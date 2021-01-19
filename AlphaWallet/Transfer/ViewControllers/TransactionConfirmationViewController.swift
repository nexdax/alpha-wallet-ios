// Copyright © 2020 Stormbird PTE. LTD.

import BigInt
import Foundation
import UIKit
import Result

protocol TransactionConfirmationViewControllerDelegate: class {
    func controller(_ controller: TransactionConfirmationViewController, continueButtonTapped sender: UIButton)
    func controllerDidTapEdit(_ controller: TransactionConfirmationViewController)
    func didClose(in controller: TransactionConfirmationViewController)
}

class TransactionConfirmationViewController: UIViewController {
    enum State {
        case ready
        case pending
        case done(withError: Bool)
    }

    private lazy var headerView: HeaderView = HeaderView(viewModel: .init(title: viewModel.navigationTitle))
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var viewModel: TransactionConfirmationViewModel

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        return scrollView
    }()

    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()

        return view
    }()

    private var contentSizeObservation: NSKeyValueObservation?

    private let loadingIndicatorView = ActivityIndicatorControl()

    private lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = viewModel.footerBackgroundColor
        view.addSubview(buttonsBar)
        view.addSubview(loadingIndicatorView)

        return view
    }()

    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissViewController))
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(tap)

        return view
    }()

    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white

        view.addSubview(scrollView)
        view.addSubview(footerBar)
        view.addSubview(headerView)
        view.addSubview(separatorLine)

        return view
    }()

    private lazy var heightConstraint: NSLayoutConstraint = {
        return containerView.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
    }()

    private lazy var bottomConstraint: NSLayoutConstraint = {
        containerView.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }()

    private var allowPresentationAnimation: Bool = true
    private var allowDismissialAnimation: Bool = true

    var canBeDismissed = true
    weak var delegate: TransactionConfirmationViewControllerDelegate?
    // swiftlint:disable function_body_length
    init(viewModel: TransactionConfirmationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(backgroundView)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            backgroundView.bottomAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            heightConstraint,
            bottomConstraint,
            containerView.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            separatorLine.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.separatorHeight),
            separatorLine.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),

            footerBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.footerHeight),
            footerBar.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor),

            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            loadingIndicatorView.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            loadingIndicatorView.centerXAnchor.constraint(equalTo: footerBar.centerXAnchor)
        ])
        headerView.closeButton.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)

        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .initial]) { [weak self] scrollView, _ in
            guard let strongSelf = self, strongSelf.allowDismissialAnimation else { return }

            let statusBarHeight = UIApplication.shared.statusBarFrame.height
            let contentHeight = scrollView.contentSize.height + DataEntry.Metric.TransactionConfirmation.footerHeight + DataEntry.Metric.TransactionConfirmation.headerHeight + UIApplication.shared.bottomSafeAreaHeight
            let newHeight = min(UIScreen.main.bounds.height - statusBarHeight, contentHeight)

            let fillScreenPercentage = strongSelf.heightConstraint.constant / strongSelf.view.bounds.height

            if fillScreenPercentage >= 0.9 {
                strongSelf.heightConstraint.constant = strongSelf.containerView.bounds.height
            } else {
                strongSelf.heightConstraint.constant = newHeight
            }
        }

        switch viewModel {
        case .dappTransaction(let dappTransactionViewModel):
            dappTransactionViewModel.ethPrice.subscribe { [weak self] cryptoToDollarRate in
                guard let strongSelf = self else { return }
                dappTransactionViewModel.cryptoToDollarRate = cryptoToDollarRate
                strongSelf.generateSubviews()
            }
        case .tokenScriptTransaction(let tokenScriptTransactionViewModel):
            tokenScriptTransactionViewModel.ethPrice.subscribe { [weak self] cryptoToDollarRate in
                guard let strongSelf = self else { return }
                tokenScriptTransactionViewModel.cryptoToDollarRate = cryptoToDollarRate
                strongSelf.generateSubviews()
            }
        case .sendFungiblesTransaction(let sendFungiblesViewModel):
            sendFungiblesViewModel.recipientResolver.resolve { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.generateSubviews()
            }

            switch sendFungiblesViewModel.transactionType {
            case .nativeCryptocurrency:
                sendFungiblesViewModel.session.balanceViewModel.subscribe { [weak self] balanceBaseViewModel in
                    guard let strongSelf = self else { return }
                    sendFungiblesViewModel.updateBalance(.nativeCryptocurrency(balanceViewModel: balanceBaseViewModel))
                    strongSelf.generateSubviews()
                }
                sendFungiblesViewModel.ethPrice.subscribe { [weak self] cryptoToDollarRate in
                    guard let strongSelf = self else { return }
                    sendFungiblesViewModel.cryptoToDollarRate = cryptoToDollarRate
                    strongSelf.generateSubviews()
                }
                sendFungiblesViewModel.session.refresh(.ethBalance)
            case .ERC20Token(let token, _, _):
                sendFungiblesViewModel.updateBalance(.erc20(token: token))
                sendFungiblesViewModel.ethPrice.subscribe { [weak self] cryptoToDollarRate in
                    guard let strongSelf = self else { return }
                    sendFungiblesViewModel.cryptoToDollarRate = cryptoToDollarRate
                    strongSelf.generateSubviews()
                }
            case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
                sendFungiblesViewModel.ethPrice.subscribe { [weak self] cryptoToDollarRate in
                    guard let strongSelf = self else { return }
                    sendFungiblesViewModel.cryptoToDollarRate = cryptoToDollarRate
                    strongSelf.generateSubviews()
                }
            }
        case .sendNftTransaction(let sendNftViewModel):
            sendNftViewModel.recipientResolver.resolve { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.generateSubviews()
            }
            sendNftViewModel.ethPrice.subscribe { [weak self] cryptoToDollarRate in
                guard let strongSelf = self else { return }
                sendNftViewModel.cryptoToDollarRate = cryptoToDollarRate
                strongSelf.generateSubviews()
            }
        case .claimPaidErc875MagicLink(let claimPaidErc875MagicLinkViewModel):
            claimPaidErc875MagicLinkViewModel.ethPrice.subscribe { [weak self] cryptoToDollarRate in
                guard let strongSelf = self else { return }
                claimPaidErc875MagicLinkViewModel.cryptoToDollarRate = cryptoToDollarRate
                strongSelf.generateSubviews()
            }
        }

        generateSubviews()
    }
    // swiftlint:enable function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        set(state: .ready)
        configure(for: viewModel)

        //NOTE: to display animation correctly we can take 'view.frame.height' and bottom view will smoothly slide up from button ;)
        bottomConstraint.constant = view.frame.height
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(true, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presentViewAnimated()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(false, animated: false)
        }
    }

    private func presentViewAnimated() {
        guard allowPresentationAnimation else { return }
        allowPresentationAnimation = false

        bottomConstraint.constant = 0

        UIView.animate(withDuration: 0.4) {
            self.view.layoutIfNeeded()
        }
    }

    func dismissViewAnimated(with completion: @escaping () -> Void) {
        guard allowDismissialAnimation else { return }
        allowDismissialAnimation = false

        bottomConstraint.constant = heightConstraint.constant

        UIView.animate(withDuration: 0.4, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            completion()
        })
    }

    func set(state: State, completion: (() -> Void)? = nil) {
        let confirmationButton = buttonsBar.buttons[0]

        switch state {
        case .ready:
            buttonsBar.isHidden = false
            loadingIndicatorView.isHidden = true
        case .pending:
            confirmationButton.startAnimation(completion: { [weak self] in
                self?.buttonsBar.isHidden = true
                self?.loadingIndicatorView.isHidden = false
                self?.loadingIndicatorView.startAnimating()
            })
        case .done(let hasError):
            buttonsBar.isHidden = true
            loadingIndicatorView.isHidden = false
            loadingIndicatorView.stopAnimating(completion: { [weak self] in
                self?.buttonsBar.isHidden = false
                self?.loadingIndicatorView.isHidden = true
                let animationStyle: StopAnimationStyle = {
                    if hasError {
                        return .shake
                    } else {
                        return .normal
                    }
                }()
                confirmationButton.stopAnimation(animationStyle: animationStyle, completion: completion)
            })
        }
    }

    @objc private func dismissViewController() {
        guard canBeDismissed else { return }
        dismissViewAnimated(with: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.didClose(in: strongSelf)
        })
    }

    func reloadView() {
        generateSubviews()
    }

    private func configure(for viewModel: TransactionConfirmationViewModel) {
        scrollView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.title

        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        button.shrinkBorderColor = Colors.loadingIndicatorBorder
        button.setTitle(viewModel.confirmationButtonTitle, for: .normal)
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
    }

    @objc func confirmButtonTapped(_ sender: UIButton) {
        delegate?.controller(self, continueButtonTapped: sender)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

fileprivate struct HeaderViewModel {
    let title: String
    var backgroundColor: UIColor {
        Colors.appBackground
    }
    var icon: UIImage? {
        return R.image.awLogoSmall()
    }
    var attributedTitle: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        return .init(string: title, attributes: [
            .font: DataEntry.Font.text as Any,
            .paragraphStyle: style,
            .foregroundColor: Colors.darkGray
        ])
    }
}

fileprivate class HeaderView: UIView {
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()

        return view
    }()

    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        return titleLabel
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    let closeButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentMode = .scaleAspectFit
        button.setImage(R.image.close(), for: .normal)

        return button
    }()

    init(viewModel: HeaderViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(separatorLine)
        addSubview(titleLabel)
        addSubview(iconImageView)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            separatorLine.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.separatorHeight),
            separatorLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor),

            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.headerHeight)
        ])

        titleLabel.attributedText = viewModel.attributedTitle
        iconImageView.image = viewModel.icon
        backgroundColor = viewModel.backgroundColor
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

extension TransactionConfirmationViewController {
    // swiftlint:disable function_body_length
    private func generateSubviews() {
        stackView.removeAllArrangedSubviews()
        var views: [UIView] = []
        switch viewModel {
        case .dappTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                var children: [UIView] = []

                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self

                switch section {
                case .gas:
                    header.enableTapAction(title: R.string.localizable.editButtonTitle())
                case .amount:
                    break
                case .function(let functionCallMetaData):
                    let isSubViewsHidden = viewModel.isSubviewsHidden(section: sectionIndex)
                    let view = TransactionConfirmationRowInfoView(viewModel: .init(title: "\(functionCallMetaData.name)()", subtitle: ""))
                    view.isHidden = isSubViewsHidden
                    children.append(view)

                    for (type, value) in functionCallMetaData.arguments {
                        let view = TransactionConfirmationRowInfoView(viewModel: .init(title: type.description, subtitle: value.description))
                        view.isHidden = isSubViewsHidden
                        children.append(view)
                    }
                }
                header.childrenStackView.addArrangedSubviews(children)
                views.append(header)
            }
        case .tokenScriptTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self
                var children: [UIView] = []
                switch section {
                case .gas:
                    header.enableTapAction(title: R.string.localizable.editButtonTitle())
                case .function:
                    let isSubViewsHidden = viewModel.isSubviewsHidden(section: sectionIndex)
                    let view = TransactionConfirmationRowInfoView(viewModel: .init(title: "\(viewModel.functionCallMetaData.name)()", subtitle: ""))
                    view.isHidden = isSubViewsHidden
                    children.append(view)

                    for (type, value) in viewModel.functionCallMetaData.arguments {
                        let view = TransactionConfirmationRowInfoView(viewModel: .init(title: type.description, subtitle: value.description))
                        view.isHidden = isSubViewsHidden
                        children.append(view)
                    }
                case .contract, .amount:
                    break
                }
                header.childrenStackView.addArrangedSubviews(children)
                views.append(header)
            }
        case .sendFungiblesTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self
                var children: [UIView] = []
                switch section {
                case .recipient:
                    for (rowIndex, row) in RecipientResolver.Row.allCases.enumerated() {
                        switch row {
                        case .ens:
                            let view = TransactionConfirmationRowInfoView(viewModel: .init(title: R.string.localizable.transactionConfirmationRowTitleEns(), subtitle: viewModel.ensName))
                            view.isHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                            children.append(view)
                        case .address:
                            let view = TransactionConfirmationRowInfoView(viewModel: .init(title: R.string.localizable.transactionConfirmationRowTitleWallet(), subtitle: viewModel.addressString))
                            view.isHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                            children.append(view)
                        }
                    }
                case .gas:
                    header.enableTapAction(title: R.string.localizable.editButtonTitle())
                case .amount, .balance:
                    break
                }
                header.childrenStackView.addArrangedSubviews(children)
                views.append(header)
            }
        case .sendNftTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self
                var children: [UIView] = []
                switch section {
                case .recipient:
                    for (rowIndex, row) in RecipientResolver.Row.allCases.enumerated() {
                        switch row {
                        case .ens:
                            let view = TransactionConfirmationRowInfoView(viewModel: .init(title: R.string.localizable.transactionConfirmationRowTitleEns(), subtitle: viewModel.ensName))
                            view.isHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                            children.append(view)
                        case .address:
                            let view = TransactionConfirmationRowInfoView(viewModel: .init(title: R.string.localizable.transactionConfirmationRowTitleWallet(), subtitle: viewModel.addressString))
                            view.isHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                            children.append(view)
                        }
                    }
                case .gas:
                    header.enableTapAction(title: R.string.localizable.editButtonTitle())
                case .tokenId:
                    break
                }
                header.childrenStackView.addArrangedSubviews(children)
                views.append(header)
            }
        case .claimPaidErc875MagicLink(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self
                switch section {
                case .gas:
                    header.enableTapAction(title: R.string.localizable.editButtonTitle())
                case .amount, .numberOfTokens:
                    break
                }
                views.append(header)
            }
        }
        stackView.addArrangedSubviews(views)
    }
    // swiftlint:enable function_body_length
}

extension TransactionConfirmationViewController: TransactionConfirmationHeaderViewDelegate {

    func headerView(_ header: TransactionConfirmationHeaderView, shouldHideChildren section: Int, index: Int) -> Bool {
        return true
    }

    func headerView(_ header: TransactionConfirmationHeaderView, shouldShowChildren section: Int, index: Int) -> Bool {
        switch viewModel {
        case .dappTransaction, .claimPaidErc875MagicLink, .tokenScriptTransaction:
            return true
        case .sendFungiblesTransaction(let viewModel):
            switch viewModel.sections[section] {
            case .recipient:
                return !viewModel.isSubviewsHidden(section: section, row: index)
            case .gas, .amount, .balance:
                return true
            }
        case .sendNftTransaction(let viewModel):
            switch viewModel.sections[section] {
            case .recipient:
                //NOTE: Here we need to make sure that this view is available to display
                return !viewModel.isSubviewsHidden(section: section, row: index)
            case .gas, .tokenId:
                return true
            }
        }
    }

    func headerView(_ header: TransactionConfirmationHeaderView, openStateChanged section: Int) {
        switch viewModel.showHideSection(section) {
        case .show:
            header.expand()
        case .hide:
            header.collapse()
        }

        UIView.animate(withDuration: 0.35) {
            self.view.layoutIfNeeded()
        }
    }

    func headerView(_ header: TransactionConfirmationHeaderView, tappedSection section: Int) {
        delegate?.controllerDidTapEdit(self)
    }
}

private extension UIBarButtonItem {
    static var appIconBarButton: UIBarButtonItem {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFit
        view.image = R.image.awLogoSmall()
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true

        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.anchorsConstraint(to: container)
        ])

        return UIBarButtonItem(customView: container)
    }
}
