import SwiftUI

struct PreferencesView: View {
    @AppStorage("colorTheme") private var colorTheme: String = "auto"
    @AppStorage("editorFont")  private var editorFont:  String = "system"

    var body: some View {
        Form {
            Picker("prefs.previewTheme", selection: $colorTheme) {
                Text("prefs.theme.auto").tag("auto")
                Text("prefs.theme.light").tag("light")
                Text("prefs.theme.dark").tag("dark")
                Text("prefs.theme.sepia").tag("sepia")
            }

            Picker("prefs.editorFont", selection: $editorFont) {
                Text("prefs.font.system").tag("system")
                Text("prefs.font.menlo").tag("menlo")
                Text("prefs.font.palatino").tag("palatino")
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}
