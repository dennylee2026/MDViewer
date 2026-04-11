import SwiftUI

struct PreferencesView: View {
    @AppStorage("colorTheme") private var colorTheme: String = "auto"
    @AppStorage("editorFont")  private var editorFont:  String = "system"

    var body: some View {
        Form {
            Picker("预览主题", selection: $colorTheme) {
                Text("跟随系统").tag("auto")
                Text("始终明亮").tag("light")
                Text("始终暗色").tag("dark")
                Text("复古纸张（Sepia）").tag("sepia")
            }

            Picker("编辑器字体", selection: $editorFont) {
                Text("系统默认（SF Pro）").tag("system")
                Text("等宽（Menlo）").tag("menlo")
                Text("衬线（Palatino）").tag("palatino")
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}
