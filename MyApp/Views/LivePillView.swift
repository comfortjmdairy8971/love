import UIKit

// MARK: - Live Timer Pill
final class LivePillView: UIView {
    enum State { case idle, running, paused }

    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    private(set) var state: State = .idle

    private let capsule = TapView()

    private let playIcon = UIImageView.symbol("play.fill", style: .headline, color: .systemPink)
    private let startLabel = UILabel.make("Start Time Together", font: .preferred(.headline), color: .systemPink)
    private lazy var idleStack = UIStackView.make(.horizontal, spacing: 8, alignment: .center, [playIcon, startLabel])

    private let dotView = UIView()
    private let timeLabel = UILabel.make(
        font: UIFontMetrics(forTextStyle: .title3).scaledFont(for: .monospacedDigitSystemFont(ofSize: 20, weight: .bold))
    )
    private let stateLabel = UILabel.make("together", font: .preferred(.caption1), color: .secondaryLabel)
    let stopButton = UIButton(configuration: .capsule(
        title: "Stop",
        symbol: "stop.fill",
        color: .systemRed,
        font: .preferred(.subheadline, weight: .bold),
        verticalPadding: 8
    ))
    private lazy var activeStack = UIStackView.make(
        .horizontal, spacing: 10, alignment: .center,
        [dotView, timeLabel, stateLabel, .spacer(), stopButton]
    )

    private var idleConstraints: [NSLayoutConstraint] = []
    private var activeConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setUpViews()
        setUpConstraints()
        applyState(animated: false)

        NotificationCenter.default.addObserver(
            self, selector: #selector(updatePulse), name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setUpViews() {
        addSubview(capsule)
        capsule.clipsToBounds = true
        capsule.layer.cornerCurve = .continuous
        capsule.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.3).cgColor
        capsule.onTap = { [weak self] in
            guard let self, self.state == .idle else { return }
            self.onStart?()
        }

        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.backgroundColor = .systemRed
        dotView.layer.cornerRadius = 5

        timeLabel.accessibilityLabel = "Elapsed time"
        startLabel.adjustsFontSizeToFitWidth = true
        startLabel.minimumScaleFactor = 0.8
        stopButton.setContentHuggingPriority(.required, for: .horizontal)
        stopButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        stopButton.addAction(UIAction { [weak self] _ in self?.onStop?() }, for: .touchUpInside)

        capsule.addSubview(idleStack)
        capsule.addSubview(activeStack)

        layer.shadowColor = UIColor.systemRed.cgColor
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowOpacity = 0
    }

    private func setUpConstraints() {
        NSLayoutConstraint.activate([
            dotView.widthAnchor.constraint(equalToConstant: 10),
            dotView.heightAnchor.constraint(equalToConstant: 10),

            capsule.topAnchor.constraint(equalTo: topAnchor),
            capsule.bottomAnchor.constraint(equalTo: bottomAnchor),
            capsule.centerXAnchor.constraint(equalTo: centerXAnchor),
            capsule.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),

            idleStack.centerXAnchor.constraint(equalTo: capsule.centerXAnchor),
            idleStack.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            activeStack.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
        ])

        // The hidden stack is only centered, so it never influences the capsule's size.
        idleConstraints = [
            idleStack.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: 22),
            idleStack.topAnchor.constraint(equalTo: capsule.topAnchor, constant: 12),
            idleStack.bottomAnchor.constraint(equalTo: capsule.bottomAnchor, constant: -12),
            activeStack.centerXAnchor.constraint(equalTo: capsule.centerXAnchor),
        ]
        activeConstraints = [
            capsule.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsule.trailingAnchor.constraint(equalTo: trailingAnchor),
            activeStack.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: 18),
            activeStack.trailingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: -6),
            activeStack.topAnchor.constraint(equalTo: capsule.topAnchor, constant: 6),
            activeStack.bottomAnchor.constraint(equalTo: capsule.bottomAnchor, constant: -6),
        ]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capsule.layer.cornerRadius = capsule.bounds.height / 2
    }

    // MARK: Updates
    func configure(state newState: State, elapsedSeconds: Int, animated: Bool) {
        setElapsed(elapsedSeconds)
        state = newState
        applyState(animated: animated)
    }

    func setElapsed(_ seconds: Int) {
        timeLabel.text = formatElapsed(seconds: seconds)
        timeLabel.accessibilityValue = formatDuration(minutes: seconds / 60)
    }

    private func applyState(animated: Bool) {
        let isIdle = state == .idle
        stateLabel.text = state == .paused ? "paused" : "together"
        NSLayoutConstraint.deactivate(isIdle ? activeConstraints : idleConstraints)
        NSLayoutConstraint.activate(isIdle ? idleConstraints : activeConstraints)

        capsule.isAccessibilityElement = isIdle
        capsule.accessibilityLabel = isIdle ? "Start Time Together" : nil
        capsule.accessibilityTraits = isIdle ? .button : []
        activeStack.accessibilityElementsHidden = isIdle
        idleStack.accessibilityElementsHidden = !isIdle
        updatePulse()

        let changes = {
            self.idleStack.alpha = isIdle ? 1 : 0
            self.activeStack.alpha = isIdle ? 0 : 1
            self.capsule.backgroundColor = isIdle
                ? UIColor.systemPink.withAlphaComponent(0.12)
                : .secondarySystemGroupedBackground
            self.capsule.layer.borderWidth = isIdle ? 0 : 1
            self.layer.shadowOpacity = self.state == .running ? 0.15 : 0
            self.layoutIfNeeded()
        }
        guard animated else { return changes() }
        UIView.animate(springDuration: 0.5, bounce: 0.3, options: [.allowUserInteraction, .beginFromCurrentState], animations: changes)
    }

    @objc private func updatePulse() {
        dotView.layer.removeAnimation(forKey: "pulse")
        guard state == .running else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.25
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.isRemovedOnCompletion = false
        dotView.layer.add(pulse, forKey: "pulse")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { updatePulse() }
    }
}
