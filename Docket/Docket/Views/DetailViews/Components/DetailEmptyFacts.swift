import SwiftUI

struct DetailEmptyFacts: View {
    var body: some View {
        Text("No extra details pinned yet.")
            .font(DocketDetailTheme.Empty.font)
            .foregroundStyle(DocketDetailTheme.Empty.color)
    }
}
