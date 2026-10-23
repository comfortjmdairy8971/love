import UIKit

/// A non-reused table cell that hosts a single persistent view (static form rows, headers).
final class ViewContainerCell: UITableViewCell {
    init(hosting view: UIView, insets: NSDirectionalEdgeInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)) {
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none
        contentView.addSubview(view)
        view.pinEdges(to: contentView, insets: insets)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
