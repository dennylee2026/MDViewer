import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var styleManager = StyleManager.shared

    var body: some View {
        Form {
            Picker("prefs.style", selection: Binding(
                get: { styleManager.activeStyle.name },
                set: { styleManager.activate($0) }
            )) {
                ForEach(styleManager.stylesFile.styles) { style in
                    Text(style.name).tag(style.name)
                }
            }

            Button("prefs.style.openConfig") {
                styleManager.openConfigFile()
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}
