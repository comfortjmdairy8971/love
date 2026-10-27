import UIKit
import PhotosUI
import SwiftUI

// MARK: - Category Detail
final class CategoryDetailViewController: UIViewController {
    private enum Section: Int, CaseIterable { case header, form, history }
    private enum FormRow { case duration, note, photo, photoPreview, save }

    private let category: ActivityCategory
    private let store = DataStore.shared
    private var logs: [ActivityLog] = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // Header
    private let headerRing: CircularProgressView
    private let progressLabel = UILabel.make(font: .preferred(.subheadline), color: .secondaryLabel, lines: 0)

    // Form
    private var durationMinutes = 30
    private var imageData: Data?
    private let durationValueLabel = UILabel.make(font: .preferred(.body), color: .secondaryLabel)
    private let stepper = UIStepper()
    private let noteField = UITextField()
    private let photoButton = UIButton(configuration: .plain())
    private let photoPreview = UIImageView()
    private let saveButton: UIButton

    private lazy var headerCell = ViewContainerCell(hosting: makeHeaderView())
    private lazy var durationCell = ViewContainerCell(hosting: makeDurationRow())
    private lazy var noteCell = ViewContainerCell(hosting: noteField)
    private lazy var photoCell = ViewContainerCell(hosting: photoButton, insets: NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    private lazy var photoPreviewCell = ViewContainerCell(hosting: makePhotoPreview())
    private lazy var saveCell = ViewContainerCell(hosting: saveButton)
    private lazy var emptyHistoryCell = ViewContainerCell(hosting: EmptyStateView(
        symbol: category.icon,
        title: String(localized: "Nothing logged yet"),
        message: String(localized: "Use +15m on the dashboard or the form above.")
    ))

    private var formRows: [FormRow] {
        imageData == nil ? [.duration, .note, .photo, .save] : [.duration, .note, .photo, .photoPreview, .save]
    }

    init(category: ActivityCategory) {
        self.category = category
        headerRing = CircularProgressView(color: category.color, lineWidth: 10)
        saveButton = UIButton(configuration: .capsule(title: String(localized: "Save Log"), color: category.color))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = category.title
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground

        setUpFormControls()
        setUpTableView()
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: .dataStoreDidChange, object: nil)

        logs = store.logs(for: category)
        updateHeader(animated: false)
    }

    // MARK: Setup
    private func setUpTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        tableView.register(ActivityLogCell.self, forCellReuseIdentifier: ActivityLogCell.reuseID)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    private func setUpFormControls() {
        stepper.minimumValue = 5
        stepper.maximumValue = 480
        stepper.stepValue = 5
        stepper.value = Double(durationMinutes)
        stepper.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.durationMinutes = Int(self.stepper.value)
            self.updateDurationLabel()
        }, for: .valueChanged)
        updateDurationLabel()

        noteField.translatesAutoresizingMaskIntoConstraints = false
        noteField.placeholder = "Add a short note..."
        noteField.font = .preferredFont(forTextStyle: .body)
        noteField.adjustsFontForContentSizeCategory = true
        noteField.clearButtonMode = .whileEditing
        noteField.returnKeyType = .done
        noteField.delegate = self
        noteField.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true

        photoButton.configuration?.image = UIImage(systemName: "photo.on.rectangle.angled")
        photoButton.configuration?.imagePadding = 10
        photoButton.configuration?.baseForegroundColor = category.color
        photoButton.contentHorizontalAlignment = .leading
        photoButton.addAction(UIAction { [weak self] _ in self?.presentPhotoPicker() }, for: .touchUpInside)
        updatePhotoButtonTitle()

        saveButton.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)
    }

    private func makeHeaderView() -> UIView {
        headerRing.isUserInteractionEnabled = false
        headerRing.isAccessibilityElement = false
        let icon = UIImageView.symbol(category.icon, style: .headline, color: category.color)
        headerRing.addSubview(icon)

        let titleLabel = UILabel.make(category.title, font: .preferred(.title3, weight: .bold))
        let infoLabel = UILabel.make(category.info, font: .preferred(.caption1), color: .secondaryLabel, lines: 0)
        let texts = UIStackView.make(.vertical, spacing: 4, [titleLabel, progressLabel, infoLabel])
        let content = UIStackView.make(.horizontal, spacing: 16, alignment: .center, [headerRing, texts])

        NSLayoutConstraint.activate([
            headerRing.widthAnchor.constraint(equalToConstant: 64),
            headerRing.heightAnchor.constraint(equalToConstant: 64),
            icon.centerXAnchor.constraint(equalTo: headerRing.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: headerRing.centerYAnchor),
        ])
        content.isAccessibilityElement = true
        return content
    }

    private func makeDurationRow() -> UIView {
        let label = UILabel.make(String(localized: "Duration"), font: .preferred(.body))
        return UIStackView.make(.horizontal, spacing: 12, alignment: .center, [label, .spacer(), durationValueLabel, stepper])
    }

    private func makePhotoPreview() -> UIView {
        photoPreview.translatesAutoresizingMaskIntoConstraints = false
        photoPreview.contentMode = .scaleAspectFill
        photoPreview.clipsToBounds = true
        photoPreview.layer.cornerRadius = 12
        photoPreview.layer.cornerCurve = .continuous
        photoPreview.isUserInteractionEnabled = true
        photoPreview.isAccessibilityElement = true
        photoPreview.accessibilityLabel = "Attached photo"

        var removeConfig = UIButton.Configuration.plain()
        removeConfig.image = UIImage(systemName: "xmark.circle.fill")
        removeConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24)
            .applying(UIImage.SymbolConfiguration(paletteColors: [.white, UIColor.black.withAlphaComponent(0.5)]))
        let removeButton = UIButton(configuration: removeConfig)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.accessibilityLabel = "Remove Photo"
        removeButton.addAction(UIAction { [weak self] _ in self?.setImageData(nil) }, for: .touchUpInside)
        photoPreview.addSubview(removeButton)

        NSLayoutConstraint.activate([
            photoPreview.heightAnchor.constraint(equalToConstant: 180),
            removeButton.topAnchor.constraint(equalTo: photoPreview.topAnchor, constant: 4),
            removeButton.trailingAnchor.constraint(equalTo: photoPreview.trailingAnchor, constant: -4),
        ])
        return photoPreview
    }

    // MARK: Updates
    private func updateDurationLabel() {
        durationValueLabel.text = formatDuration(minutes: durationMinutes)
        stepper.accessibilityLabel = "Duration"
        stepper.accessibilityValue = formatDuration(minutes: durationMinutes)
    }

    private func updatePhotoButtonTitle() {
        photoButton.configuration?.title = imageData == nil ? "Attach Photo" : "Change Photo"
    }

    private func updateHeader(animated: Bool) {
        let weekMinutes = logs.minutesByCategory(in: Calendar.current.weekInterval(containing: .now))[category] ?? 0
        let target = store.targetMinutes(for: category)
        let progress = min(Double(weekMinutes) / Double(max(target, 1)), 1)
        headerRing.setProgress(progress, animated: animated)
        progressLabel.text = "\(Int(progress * 100))% · \(weekMinutes) / \(target) mins this week"
        headerCell.contentView.subviews.first?.accessibilityLabel = "\(category.title). \(progressLabel.text ?? "")"
    }

    @objc private func dataDidChange(_ notification: Notification) {
        guard (notification.object as AnyObject?) !== self else { return }
        logs = store.logs(for: category)
        updateHeader(animated: view.window != nil)
        tableView.reloadSections(IndexSet(integer: Section.history.rawValue), with: .automatic)
    }

    private func setImageData(_ data: Data?) {
        let hadPreview = imageData != nil
        imageData = data
        photoPreview.image = data.flatMap(UIImage.init(data:))
        updatePhotoButtonTitle()

        let previewPath = IndexPath(row: 3, section: Section.form.rawValue)
        switch (hadPreview, data != nil) {
        case (false, true): tableView.insertRows(at: [previewPath], with: .fade)
        case (true, false): tableView.deleteRows(at: [previewPath], with: .fade)
        default: break
        }
    }

    // MARK: Actions
    private func save() {
        let note = (noteField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        store.insert(
            ActivityLog(category: category, durationMinutes: durationMinutes, note: note, imageData: imageData),
            from: self
        )
        Haptics.success()

        let wasEmpty = logs.isEmpty
        logs = store.logs(for: category)
        noteField.text = ""
        noteField.resignFirstResponder()
        setImageData(nil)
        updateHeader(animated: true)

        let firstHistoryRow = IndexPath(row: 0, section: Section.history.rawValue)
        if wasEmpty {
            tableView.reloadRows(at: [firstHistoryRow], with: .fade)
        } else {
            tableView.insertRows(at: [firstHistoryRow], with: .top)
        }
    }

    private func deleteLog(at indexPath: IndexPath) {
        let log = logs.remove(at: indexPath.row)
        store.delete(log, from: self)
        if logs.isEmpty {
            tableView.reloadRows(at: [indexPath], with: .fade)
        } else {
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        updateHeader(animated: true)
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// Re-encodes picked photos as JPEG capped at 2048px so the store stays small.
    nonisolated private static func compressedJPEG(from image: UIImage, maxDimension: CGFloat = 2048) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image.jpegData(compressionQuality: 0.85) }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return (image.preparingThumbnail(of: size) ?? image).jpegData(compressionQuality: 0.85)
    }
}

// MARK: - Table Data Source & Delegate
extension CategoryDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .header: 1
        case .form: formRows.count
        case .history: max(logs.count, 1)
        case nil: 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .form: "Log an Activity"
        case .history: "History"
        default: nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .header:
            return headerCell
        case .form:
            switch formRows[indexPath.row] {
            case .duration: return durationCell
            case .note: return noteCell
            case .photo: return photoCell
            case .photoPreview: return photoPreviewCell
            case .save: return saveCell
            }
        case .history, nil:
            guard !logs.isEmpty else { return emptyHistoryCell }
            let cell = tableView.dequeueReusableCell(withIdentifier: ActivityLogCell.reuseID, for: indexPath) as! ActivityLogCell
            cell.configure(with: logs[indexPath.row], color: category.color)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool { false }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == Section.history.rawValue, !logs.isEmpty else { return nil }
        let delete = UIContextualAction(style: .destructive, title: String(localized: "Delete")) { [weak self] _, _, completion in
            self?.deleteLog(at: indexPath)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

// MARK: - Text Field
extension CategoryDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Photo Picker
extension CategoryDetailViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            let data = Self.compressedJPEG(from: image)
            Task { @MainActor [weak self] in
                self?.setImageData(data)
            }
        }
    }
}

#Preview {
    UINavigationController(rootViewController: CategoryDetailViewController(category: .goingOut))
}
