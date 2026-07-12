import SwiftUI
import ContactsUI

/// Native contact picker; returns the selected contact's display name.
/// (Real membership is established when the friend opens the invite link —
/// picking a contact here pre-fills who you intend to invite.)
struct ContactPicker: UIViewControllerRepresentable {
    var onSelect: (String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (String) -> Void
        init(onSelect: @escaping (String) -> Void) { self.onSelect = onSelect }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            onSelect(name.isEmpty ? "Friend" : name)
        }
    }
}
