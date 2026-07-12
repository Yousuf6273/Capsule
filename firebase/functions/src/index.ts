/**
 * Capsule Cloud Functions — the only code allowed to unlock a vault.
 * Clients cannot write `state`; security rules block it. These functions run
 * with Admin SDK privileges and are the single gate for the reveal.
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

/** Every minute, unlock date-based vaults whose time has come. */
export const unlockDueVaults = onSchedule("every 1 minutes", async () => {
  const due = await db
    .collection("vaults")
    .where("state", "==", "sealed")
    .where("unlockAt", "<=", Timestamp.now())
    .get();

  await Promise.all(due.docs.map((doc) => unlockVault(doc.id)));
});

/** Callable: member marks themselves ready; unlocks when everyone is. */
export const markReady = onCall(async (request) => {
  const uid = request.auth?.uid;
  const vaultId = request.data?.vaultId as string;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (!vaultId) throw new HttpsError("invalid-argument", "vaultId required.");

  const ref = db.doc(`vaults/${vaultId}`);
  const shouldUnlock = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Vault not found.");
    const vault = snap.data()!;
    if (!vault.memberIds.includes(uid)) {
      throw new HttpsError("permission-denied", "Not a member of this vault.");
    }
    tx.update(ref, { readyMemberIds: FieldValue.arrayUnion(uid) });
    const ready = new Set([...(vault.readyMemberIds ?? []), uid]);
    return (
      vault.unlockCondition === "everyoneReady" &&
      vault.memberIds.every((m: string) => ready.has(m))
    );
  });

  if (shouldUnlock) await unlockVault(vaultId);
  return { unlocked: shouldUnlock };
});

/** Callable: join a vault by invite code (codes are not client-readable). */
export const joinByInviteCode = onCall(async (request) => {
  const uid = request.auth?.uid;
  const code = (request.data?.code as string)?.toUpperCase()?.trim();
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (!code) throw new HttpsError("invalid-argument", "code required.");

  const codeSnap = await db.doc(`inviteCodes/${code}`).get();
  if (!codeSnap.exists) throw new HttpsError("not-found", "Invalid invite code.");
  const vaultId = codeSnap.data()!.vaultId as string;

  await db.doc(`vaults/${vaultId}`).update({
    memberIds: FieldValue.arrayUnion(uid),
  });
  await notifyVault(vaultId, "New member joined", "Someone just joined your capsule 🎟", uid);
  return { vaultId };
});

/** Notify members when a memory is sealed (throttling TODO: batch per hour). */
export const onMemorySealed = onDocumentCreated(
  "vaults/{vaultId}/memories/{memoryId}",
  async (event) => {
    const vaultId = event.params.vaultId;
    await db.doc(`vaults/${vaultId}`).update({
      memoryCount: FieldValue.increment(1),
    });
  }
);

/**
 * The single unlock gate: flips state, computes recap stats + quiz answer key
 * while media metadata is still server-only, then notifies everyone.
 */
async function unlockVault(vaultId: string): Promise<void> {
  const memories = await db.collection(`vaults/${vaultId}/memories`).get();

  const perMember: Record<string, number> = {};
  const perDay: Record<string, number> = {};
  let totalBytes = 0;
  let earliest: FirebaseFirestore.DocumentData | null = null;
  let latest: FirebaseFirestore.DocumentData | null = null;

  memories.forEach((doc) => {
    const m = doc.data();
    perMember[m.uploaderId] = (perMember[m.uploaderId] ?? 0) + 1;
    const day = m.capturedAt.toDate().toISOString().slice(0, 10);
    perDay[day] = (perDay[day] ?? 0) + 1;
    totalBytes += m.byteSize ?? 0;
    if (!earliest || m.capturedAt < earliest.capturedAt) earliest = m;
    if (!latest || m.capturedAt > latest.capturedAt) latest = m;
  });

  const busiestDay = Object.entries(perDay).sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

  await db.doc(`vaults/${vaultId}/recap/stats`).set({
    totalMemories: memories.size,
    totalBytes,
    perMemberCounts: perMember,
    perDayCounts: perDay,
    busiestDay,
    earliestMemoryId: earliest ? (earliest as any).id ?? null : null,
    latestMemoryId: latest ? (latest as any).id ?? null : null,
    computedAt: FieldValue.serverTimestamp(),
  });

  await db.doc(`vaults/${vaultId}`).update({
    state: "unlocked",
    unlockedAt: FieldValue.serverTimestamp(),
  });

  await notifyVault(vaultId, "It's time 🔓", "Your capsule just unlocked. Open it together!");
}

async function notifyVault(
  vaultId: string,
  title: string,
  body: string,
  excludeUid?: string
): Promise<void> {
  const vault = (await db.doc(`vaults/${vaultId}`).get()).data();
  if (!vault) return;
  const uids: string[] = vault.memberIds.filter((m: string) => m !== excludeUid);
  const tokens: string[] = [];
  for (const uid of uids) {
    const user = (await db.doc(`users/${uid}`).get()).data();
    if (user?.fcmToken) tokens.push(user.fcmToken);
  }
  if (tokens.length === 0) return;
  await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { vaultId },
  });
}
