import SwiftUI

func imageFromData(_ data: Data?) -> Image? {
    guard let data, let ui = UIImage(data: data) else { return nil }
    return Image(uiImage: ui)
}

struct Thumbnail: View {
    let data: Data?
    var body: some View {
        if let img = imageFromData(data) {
            img.resizable().scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }
}
