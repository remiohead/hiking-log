import SwiftUI
import MapKit

struct HikeMapView: View {
    @Environment(HikeStore.self) private var store
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.5, longitude: -121.8),
        span: MKCoordinateSpan(latitudeDelta: 3.5, longitudeDelta: 5.0)
    ))
    @State private var selectedTrail: TrailSummary?
    @Environment(\.colorScheme) private var colorScheme

    private let presets: [(String, MKCoordinateRegion)] = [
        ("All Washington", MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.4, longitude: -120.8),
            span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 8.0)
        )),
        ("Western WA", MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.8, longitude: -122.8),
            span: MKCoordinateSpan(latitudeDelta: 2.2, longitudeDelta: 3.3)
        )),
        ("I-90 Corridor", MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.45, longitude: -121.7),
            span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 1.4)
        )),
        ("Snoqualmie Area", MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.42, longitude: -121.38),
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.55)
        )),
        ("Seattle Metro", MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.52, longitude: -122.35),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.4)
        )),
        ("North Cascades", MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.5, longitude: -121.5),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 2.5)
        )),
        ("Olympics", MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.7, longitude: -123.5),
            span: MKCoordinateSpan(latitudeDelta: 1.3, longitudeDelta: 2.3)
        ))
    ]

    var body: some View {
        HSplitView {
            // Map
            ZStack(alignment: .topLeading) {
                Map(position: $position, selection: $selectedTrail) {
                    ForEach(store.trailSummaries()) { trail in
                        Annotation(trail.name, coordinate: trail.coordinate, anchor: .center) {
                            TrailPin(trail: trail, isSelected: selectedTrail == trail)
                                .onTapGesture {
                                    selectedTrail = trail
                                }
                        }
                        .tag(trail)
                    }
                }
                .mapStyle(colorScheme == .dark
                    ? .standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .including([.nationalPark, .park]))
                    : .standard(elevation: .realistic))

                // View preset buttons
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(presets, id: \.0) { name, region in
                        Button(name) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                position = .region(region)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.caption)
                    }
                }
                .padding(8)
            }
            .frame(minWidth: 500)

            // Detail sidebar
            VStack {
                if let trail = selectedTrail {
                    TrailDetailPanel(trail: trail, store: store)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Select a trail on the map")
                            .foregroundStyle(.secondary)
                        Text("\(store.trailSummaries().count) unique trails")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxHeight: .infinity)
                }

            }
            .frame(width: 260)
        }
    }
}

struct TrailPin: View {
    let trail: TrailSummary
    let isSelected: Bool

    var body: some View {
        let size = max(14, min(36, CGFloat(trail.count) * 4))
        Circle()
            .fill(HikeStore.color(for: trail.region).opacity(isSelected ? 1.0 : 0.75))
            .stroke(isSelected ? Color.white : Color.white.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            .frame(width: size, height: size)
            .shadow(color: isSelected ? .white.opacity(0.5) : .clear, radius: 4)
    }
}

struct TrailDetailPanel: View {
    let trail: TrailSummary
    let store: HikeStore

    private var hikesForTrail: [Hike] {
        store.hikes.filter { $0.trailName == trail.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(trail.name)
                    .font(.title2.bold())

                HStack(spacing: 6) {
                    Circle()
                        .fill(HikeStore.color(for: trail.region))
                        .frame(width: 10, height: 10)
                    Text(trail.region)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                DetailRow(label: "Times Hiked", value: "\(trail.count)", highlight: true)
                DetailRow(label: "Avg Distance", value: String(format: "%.1f mi", trail.avgMiles))
                DetailRow(label: "Avg Elevation", value: "\(trail.avgElevation.formatted()) ft")
                DetailRow(label: "Last Visited", value: trail.lastHiked)

                Divider()

                Text("History")
                    .font(.headline)
                    .padding(.top, 4)

                ForEach(hikesForTrail) { hike in
                    HStack {
                        Text(hike.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(hike.distanceMiles, specifier: "%.1f") mi")
                            .font(.caption)
                        Text("\(Int(hike.elevationGainFt).formatted()) ft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(highlight ? .bold : .regular)
                .foregroundStyle(highlight ? .green : .primary)
        }
        .font(.subheadline)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
