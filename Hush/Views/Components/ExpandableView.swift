import SwiftUI

/// Colours and fonts injected into ``ExpandableView``'s header row.
/// Defined as a top-level type so callers don't need a generic placeholder to reference it.
public struct ExpandableStyle {
    public var titleFont: Font
    public var titleColor: Color
    public var chevronColor: Color

    public init(
        titleFont: Font  = .footnote.weight(.semibold),
        titleColor: Color  = Color.primary.opacity(0.75),
        chevronColor: Color = Color.primary.opacity(0.45)
    ) {
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.chevronColor = chevronColor
    }
}

/// A disclosure-style container with an animated chevron and spring-driven expand/collapse.
///
/// All visual parameters are injected via ``ExpandableView/Style`` so the view has zero
/// environment coupling and can be dropped anywhere without extra environment setup.
///
/// ```swift
/// ExpandableView("Sleep timer", isExpanded: $isExpanded) {
///     TimerControls()
/// }
///
/// // Custom style
/// ExpandableView(
///     "Sleep timer",
///     isExpanded: $isExpanded,
///     style: ExpandableView.Style(titleColor: .accentColor)
/// ) {
///     TimerControls()
/// }
/// ```
public struct ExpandableView<Content: View>: View {

    // MARK: – Style
    public typealias Style = ExpandableStyle

    // MARK: – Properties

    private let title: String
    private let style: Style
    @Binding private var isExpanded: Bool

    /// Stored as `Content` (not a closure) so SwiftUI can diff and skip unchanged subtrees.
    @ViewBuilder private let content: Content

    // MARK: – Init

    public init(
        _ title: String,
        isExpanded: Binding<Bool>,
        style: Style = Style(),
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.style = style
        self.content = content()
    }

    // MARK: – Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if isExpanded {
                content
                    .padding(.top, 10)
                    .transition(
                        .scale(scale: 0.88).combined(with: .opacity)
                    )
                    .animation(.easeInOut, value: isExpanded)
            }
        }
        .clipped()
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
    }
}

private extension ExpandableView {
    var headerRow: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(style.titleFont)
                    .foregroundStyle(style.titleColor)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.chevronColor)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(isExpanded ? "Collapse" : "Expand"))
        .accessibilityAddTraits(.isButton)
    }
}
