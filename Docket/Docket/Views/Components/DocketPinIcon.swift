import SwiftUI

/// The brass SF Symbol pushpin used for Docket's branded loading moments.
struct DocketPinIcon: View {
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: size))
            .foregroundStyle(DocketTheme.brass)
    }
}
