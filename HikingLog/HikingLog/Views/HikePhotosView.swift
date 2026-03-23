import SwiftUI
import Photos
import CoreLocation

// Shared helper to fetch photos by date + location proximity
enum PhotoFetcher {
    /// Fetch photos taken on a given date near a coordinate.
    /// radiusMiles controls how close a photo must be to be included.
    static func fetch(date: String, lat: Double, lon: Double, radiusMiles: Double = 5.0) async -> (authorized: Bool, assets: [PHAsset]) {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return (false, [])
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let start = fmt.date(from: date) else { return (true, []) }
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            start as NSDate,
            end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        let hikeLocation = CLLocation(latitude: lat, longitude: lon)
        let radiusMeters = radiusMiles * 1609.344

        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            if let photoLoc = asset.location {
                if hikeLocation.distance(from: photoLoc) <= radiusMeters {
                    fetched.append(asset)
                }
            }
        }
        return (true, fetched)
    }
}

// MARK: - Full photos popup (from camera button in log)

struct HikePhotosView: View {
    let date: String
    let trailName: String
    let lat: Double
    let lon: Double
    @State private var assets: [PHAsset] = []
    @State private var authorized = true
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.secondary)
                Text("Photos — \(trailName)")
                    .font(.headline)
                Spacer()
                Text(date)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            if !authorized {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Photos access denied")
                        .font(.callout)
                    Text("Grant access in System Settings > Privacy & Security > Photos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        #if os(macOS)
                        openURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")!)
                        #else
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !loaded {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if assets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No photos found near this hike")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text("\(assets.count) photo\(assets.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 4)
                    ], spacing: 4) {
                        ForEach(0..<assets.count, id: \.self) { index in
                            PhotoThumbnail(asset: assets[index])
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 540, height: 460)
        .task {
            let result = await PhotoFetcher.fetch(date: date, lat: lat, lon: lon)
            authorized = result.authorized
            assets = result.assets
            loaded = true
        }
    }
}

// MARK: - Photo Thumbnail

private func platformImage(_ img: PlatformImage) -> Image {
    #if os(macOS)
    Image(nsImage: img)
    #else
    Image(uiImage: img)
    #endif
}

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: PlatformImage?
    @State private var isHovered = false

    var body: some View {
        ZStack {
            if let image {
                platformImage(image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 80, minHeight: 80)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .shadow(radius: isHovered ? 4 : 0)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            openPhoto()
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        let size = CGSize(width: 400, height: 400)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { result, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if let result {
                    Task { @MainActor in
                        self.image = result
                    }
                }
                if !isDegraded {
                    continuation.resume()
                }
            }
        }
    }

    private func openPhoto() {
        #if os(macOS)
        // Get the full-size image URL and open it with Quick Look / Preview
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        asset.requestContentEditingInput(with: options) { input, _ in
            if let url = input?.fullSizeImageURL {
                openURL(url)
            }
        }
        #else
        // On iOS, open the Photos app
        openURL(URL(string: "photos://")!)
        #endif
    }
}

// MARK: - Compact photo strip for the detail popover

struct HikePhotosStrip: View {
    let date: String
    let lat: Double
    let lon: Double
    @State private var assets: [PHAsset] = []
    @State private var loaded = false

    var body: some View {
        if !loaded {
            ProgressView()
                .controlSize(.small)
                .frame(height: 20)
                .task {
                    let result = await PhotoFetcher.fetch(date: date, lat: lat, lon: lon)
                    assets = result.assets
                    loaded = true
                }
        } else if assets.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(.secondary)
                    Text("Photos")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(assets.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(0..<min(assets.count, 20), id: \.self) { index in
                            PhotoThumbnail(asset: assets[index])
                                .frame(width: 80, height: 80)
                        }
                        if assets.count > 20 {
                            Text("+\(assets.count - 20)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, height: 80)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
        }
    }
}
