import SwiftUI

struct CreateOrderView: View {
    @State private var viewModel = CreateOrderViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: CreateOrderViewModel.Field?

    var body: some View {
        Form {
            Section("Customer Contact Info") {
                field("First Name", text: $viewModel.draft.firstName, focus: .firstName)
                    .textContentType(.givenName)
                field("Last Name", text: $viewModel.draft.lastName, focus: .lastName)
                    .textContentType(.familyName)
                field("Phone", text: $viewModel.draft.phone, focus: .phone)
                    .keyboardType(.phonePad).textContentType(.telephoneNumber)
                field("Email", text: $viewModel.draft.email, focus: .email)
                    .keyboardType(.emailAddress).textContentType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section("Shipment Address") {
                field("Street 1", text: $viewModel.draft.shipmentAddress.street1, focus: .shipmentStreet1)
                field("Street 2", text: optionalText($viewModel.draft.shipmentAddress.street2), focus: .shipmentStreet2)
                field("City", text: $viewModel.draft.shipmentAddress.city, focus: .shipmentCity)
                field("State", text: $viewModel.draft.shipmentAddress.state, focus: .shipmentState)
                field("ZIP", text: $viewModel.draft.shipmentAddress.zip, focus: .shipmentZIP)
                    .keyboardType(.numberPad)
            }
            Section("Shipment Method") {
                Menu {
                    ForEach(viewModel.shippingOptions, id: \.speed.rawValue) { option in
                        Button(option.title) {
                            viewModel.selectShippingSpeed(option.speed)
                        }
                    }
                } label: {
                    LabeledContent("Shipping Speed", value: viewModel.shippingSpeedText)
                }
                .foregroundStyle(.primary)
                .accessibilityLabel("Shipping Speed")
                .accessibilityValue(viewModel.shippingSpeedText)
            }
            Section("Payment Information") {
                field("Credit Card Number", text: $viewModel.draft.paymentMethod.creditCardNumber, focus: .creditCardNumber)
                    .keyboardType(.numberPad).textContentType(.creditCardNumber)
                DisclosureGroup {
                    DatePicker(
                        "Expiration Date",
                        selection: Binding(
                            get: { viewModel.draft.paymentMethod.expirationDate },
                            set: { viewModel.selectExpirationDate($0) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                } label: {
                    LabeledContent("Expiration Date", value: viewModel.expirationDateText)
                        .accessibilityLabel("Expiration Date")
                        .accessibilityValue(viewModel.expirationDateText)
                }
                field("CVV", text: $viewModel.draft.paymentMethod.cvv, focus: .cvv)
                    .keyboardType(.decimalPad)
            }
            Section("Billing Address") {
                Toggle("Same as shipping address", isOn: $viewModel.sameAsShippingAddress)
                field("Street 1", text: $viewModel.draft.billingAddress.street1, focus: .billingStreet1)
                field("Street 2", text: optionalText($viewModel.draft.billingAddress.street2), focus: .billingStreet2)
                field("City", text: $viewModel.draft.billingAddress.city, focus: .billingCity)
                field("State", text: $viewModel.draft.billingAddress.state, focus: .billingState)
                field("ZIP", text: $viewModel.draft.billingAddress.zip, focus: .billingZIP)
                    .keyboardType(.numberPad)
            }
        }
        .formStyle(.grouped)
        .disabled(viewModel.isSaving)
        .navigationTitle("Create Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { viewModel.save() }
                    .disabled(viewModel.isSaving || viewModel.didSave)
                    .accessibilityIdentifier("save-order")
            }
        }
        .alert(viewModel.failureTitle, isPresented: $viewModel.showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please correct your order and submit again.")
        }
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave { dismiss() }
        }
    }

    private func field(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        focus: CreateOrderViewModel.Field
    ) -> some View {
        HStack {
            Text(title)
            TextField(title, text: text)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: focus)
                .submitLabel(viewModel.nextField(after: focus) == nil ? .done : .next)
                .onSubmit { focusedField = viewModel.nextField(after: focus) }
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = focus }
    }

    private func optionalText(_ text: Binding<String?>) -> Binding<String> {
        Binding(get: { text.wrappedValue ?? "" }, set: { text.wrappedValue = $0 })
    }
}
