import SwiftUI
import Lottie

private let telegramBlue = Color(hex: 0x299ff6)
private let pageBackground = Color(hex: 0x18242e)

@MainActor
final class GiftLockModel: ObservableObject {
    @Published var snapshot = GiftSnapshot(gifts: DemoGiftService.sampleGifts, locked: true, stars: 1200, receipts: [])
    @Published var activeReview: GiftReview?
    @Published var receipt: GiftReceipt?
    @Published var password = ""
    @Published var error = ""
    @Published var enteringPassword = false
    @Published var busy = false
    @Published var showSettings = false
    @Published var showCollection = false
    @Published var showRecipients = false
    @Published var showSaleOptions = false
    @Published var tapTarget: String?
    @Published var tourCaption = ""
    @Published var tourRunning = false
    private var service: any GiftLockService = DemoGiftService()
    private let session = DemoGiftService.phoneSession

    func refresh() async { snapshot = await service.snapshot() }
    func begin(_ intent: GiftIntent) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            let review = try await service.review(intent, session: session)
            receipt = nil; password = ""; error = ""; enteringPassword = false
            activeReview = review
        } catch { self.error = error.localizedDescription }
    }
    func proceed() async {
        guard let review = activeReview else { return }
        if review.requiresPassword { enteringPassword = true } else { await commit() }
    }
    func commit() async {
        guard let review = activeReview, !busy else { return }
        busy = true; defer { busy = false; password = "" }
        do {
            receipt = try await service.commit(review.id, password: password, session: session)
            error = ""; await refresh()
        } catch { self.error = error.localizedDescription }
    }
    func cancel() {
        if let review = activeReview {
            let authority = service
            let id = review.id
            let session = session
            Task { await authority.cancel(id, session: session) }
        }
        activeReview = nil; password = ""; error = ""; receipt = nil; enteringPassword = false
    }
    func reset(locked: Bool = true) async {
        cancel(); service = DemoGiftService(initiallyLocked: locked); await refresh()
    }
    func runTour() async {
        guard !tourRunning else { return }
        tourRunning = true
        await reset(locked: false)
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        func tap(_ target: String) async {
            tapTarget = target; await pause(0.28); tapTarget = nil
        }
        tourCaption = ""
        showSettings = true
        await pause(1.1)
        await tap("lockToggle")
        // The guided recording supplies the known fictional credential. This uses
        // the same policy authority as the interactive password-gated setting.
        do {
            let review = try await service.review(.setLock(enabled: true), session: session)
            _ = try await service.commit(review.id, password: DemoGiftService.samplePassword, session: session)
            await refresh()
        } catch { self.error = error.localizedDescription }
        await pause(0.9)
        showSettings = false
        await pause(0.6)
        await tap("transfer")
        showRecipients = true
        await pause(1.4)
        await tap("recipient")
        showRecipients = false
        await pause(0.45)
        await begin(.transfer(giftID: "nail-4465", recipientID: DemoGiftService.recipient.id))
        await pause(2)
        await tap("authorize")
        await proceed()
        await pause(0.8)
        password = "incorrect-demo-password"
        await pause(0.7)
        await tap("authorize")
        await commit()
        await pause(1.8)
        password = DemoGiftService.samplePassword
        await pause(0.7)
        await tap("authorize")
        await commit()
        await pause(2.2)
        await tap("done")
        cancel()
        await reset()
        await pause(0.7)
        await begin(.acceptOffer(offerID: "sample-offer-1"))
        await pause(1.8)
        await tap("authorize")
        await proceed()
        await pause(1.1)
        cancel()
        await pause(1.5)
        tourCaption = ""; tourRunning = false
    }
}

@main
struct GiftLockApp: App {
    @StateObject private var model = GiftLockModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            GiftsView(model: model)
                .tint(telegramBlue)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { model.password = "" }
                    if phase == .background { model.cancel() }
                }
                .task {
                    await model.refresh()
                    if ProcessInfo.processInfo.arguments.contains("--demo-tour") {
                        await model.runTour()
                    }
                }
        }
    }
}

// The public gift artwork is rendered locally. This view has no Telegram account connection.
struct GiftsView: View {
    @ObservedObject var model: GiftLockModel
    @State private var closed = false
    @State private var showLocalInfo = false
    private var ownsDemoCopy: Bool { model.snapshot.gifts.contains { $0.id == "nail-4465" } }
    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - 12, 470.0)
            let scale = width / 680.0
            ZStack {
                Color(hex: 0x070b0e).ignoresSafeArea()
                if closed {
                    VStack(spacing: 22) {
                        Text("Gift preview").font(.title2.weight(.semibold))
                        NailBraceletAnimation().frame(width: 200, height: 200)
                        Text("Nail Bracelet #4465").font(.headline)
                        Button("Open Gift") { closed = false }.buttonStyle(.borderedProminent)
                        Text("Offline prototype · no Telegram account connection").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            giftHeader(width: width, scale: scale)
                            giftBody(scale: scale)
                        }
                        .frame(width: width)
                        .background(pageBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 40 * scale))
                        .padding(.top, 50 * scale)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .sheet(item: $model.activeReview, onDismiss: { model.cancel() }) { review in
            GiftReviewSheet(model: model, review: review)
                .presentationDetents(model.receipt != nil ? [.height(390)] : model.enteringPassword ? [.large] : [.height(review.isPolicy ? 370 : 570)])
                .presentationDragIndicator(.visible).presentationCornerRadius(26)
        }
        .sheet(isPresented: $model.showRecipients) {
            recipientPicker.presentationDetents([.height(365)]).presentationDragIndicator(.visible).presentationCornerRadius(26)
        }
        .sheet(isPresented: $model.showSaleOptions) {
            saleOptions.presentationDetents([.height(430)]).presentationDragIndicator(.visible).presentationCornerRadius(26)
        }
        .sheet(isPresented: $model.showSettings) {
            LockSettingsView(model: model).presentationDetents([.height(440)]).presentationDragIndicator(.visible).presentationCornerRadius(26)
        }
        .alert("Offline preview", isPresented: $showLocalInfo) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.error.isEmpty ? "This screen uses public gift artwork. Your real bracelet and Telegram account are not connected to this app." : model.error + " Reset the demo from the menu to try again.") }
        .onChange(of: model.error) { _, value in if !value.isEmpty && model.activeReview == nil { showLocalInfo = true } }
    }
    private func giftHeader(width: CGFloat, scale s: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RadialGradient(colors: [Color(hex: 0xd08b6d), Color(hex: 0xb05770)], center: UnitPoint(x: 0.5, y: 0.37), startRadius: 0, endRadius: width * 0.68)
            PepperBackdrop()
            NailBraceletAnimation().frame(width: 250 * s, height: 250 * s).offset(y: 36 * s)
            HStack {
                Button { closed = true } label: { circleControl("xmark", scale: s) }.accessibilityLabel("Close gift")
                Spacer()
                Menu {
                    Button(model.snapshot.locked ? "Gift Lock · On" : "Gift Lock · Off", systemImage: "lock.shield") { model.showSettings = true }
                        .accessibilityIdentifier("giftLockSettings")
                    Button("Purchase Offers", systemImage: "tag") { model.showSaleOptions = true }
                    Button("Play Demo", systemImage: "play") { Task { await model.runTour() } }
                    Button("Reset Demo", systemImage: "arrow.counterclockwise") { Task { await model.reset() } }
                } label: { circleControl("ellipsis", scale: s) }
                    .accessibilityIdentifier("giftMenu").overlay { DemoTap(visible: model.tapTarget == "settings") }
            }.padding(.horizontal, 20 * s).padding(.top, 20 * s)
            // Position the same title, subtitle and controls as the supplied 680px-wide panel.
        }
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Nail Bracelet ").foregroundStyle(.white)
                    Text("#4465").foregroundStyle(Color(hex: 0xffd9d8))
                }.font(.system(size: 36 * s, weight: .medium)).padding(.top, 291 * s)
                Text("Rose Gold").font(.system(size: 28 * s)).foregroundStyle(Color(hex: 0xffd9d8)).padding(.top, 14 * s)
                HStack(spacing: 20 * s) {
                    giftAction("Transfer", symbol: "diamond.fill", scale: s) { model.showRecipients = true }
                        .accessibilityIdentifier("beginTransfer").overlay { DemoTap(visible: model.tapTarget == "transfer") }
                    giftAction("Wear", symbol: "crown.fill", scale: s) { showLocalInfo = true }
                    giftAction("Sell", symbol: "tag.fill", scale: s) { model.showSaleOptions = true }
                        .accessibilityIdentifier("saleOptions")
                }.padding(.horizontal, 20 * s).padding(.top, 38 * s)
            }
        }
        .frame(height: 556 * s)
        .clipped()
    }
    private func circleControl(_ symbol: String, scale s: CGFloat) -> some View {
        Image(systemName: symbol).font(.system(size: 31 * s, weight: symbol == "ellipsis" ? .bold : .regular))
            .foregroundStyle(.white).frame(width: 72 * s, height: 72 * s)
            .background(Color(hex: 0xce7b50), in: Circle())
            .overlay(Circle().stroke(Color(hex: 0xf1b484).opacity(0.9), lineWidth: 2 * s))
    }
    private func giftAction(_ title: String, symbol: String, scale s: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9 * s) {
                Group {
                    if title == "Transfer" { TransferGiftIcon().frame(width: 44 * s, height: 44 * s) }
                    else { Image(systemName: symbol).font(.system(size: 39 * s, weight: .medium)).frame(height: 44 * s) }
                }
                Text(title).font(.system(size: 27 * s))
            }.foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 120 * s)
                .background(Color(hex: 0xce7b50), in: RoundedRectangle(cornerRadius: 40 * s))
                .overlay(RoundedRectangle(cornerRadius: 40 * s).stroke(Color(hex: 0xf1b484), lineWidth: 2 * s))
        }.buttonStyle(.plain)
    }
    private func giftBody(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                infoRow("Owner", scale: s) {
                    HStack(spacing: 11 * s) {
                        Text("L").font(.system(size: 21 * s, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 40 * s, height: 40 * s)
                            .background(LinearGradient(colors: [Color(hex: 0xffdc8b), Color(hex: 0xffb58f)], startPoint: .top, endPoint: .bottom), in: Circle())
                        Text("Levi").foregroundStyle(telegramBlue)
                        Image(systemName: "sparkles").foregroundStyle(telegramBlue).font(.system(size: 22 * s))
                    }
                }
                infoRow("Model", scale: s) { attribute("Rose Gold", rarity: "3.5%", scale: s) }
                infoRow("Symbol", scale: s) { attribute("Chili Pepper", rarity: "0.4%", scale: s) }
                infoRow("Backdrop", scale: s) { attribute("Mystic Pearl", rarity: "1.2%", scale: s) }
                infoRow("Availability", scale: s) { Text("4,696/4,818 issued") }
                infoRow("Value", scale: s) {
                    HStack(spacing: 10 * s) { Text("₪ 834.00"); Text("learn more").font(.system(size: 23 * s)).foregroundStyle(telegramBlue).padding(.horizontal, 10 * s).padding(.vertical, 3 * s).background(telegramBlue.opacity(0.2), in: Capsule()) }
                }
                HStack(alignment: .center, spacing: 8) {
                    (Text("Gifted by ").foregroundStyle(.white) + Text("Dmitry Warsz").foregroundStyle(telegramBlue) + Text(" to ").foregroundStyle(.white) + Text("Poiagust").foregroundStyle(telegramBlue) + Text(" on\n14/02/25.").foregroundStyle(.white))
                        .font(.system(size: 26 * s)).lineSpacing(3 * s).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "trash").font(.system(size: 24 * s)).foregroundStyle(telegramBlue).padding(.trailing, 8 * s)
                }.padding(.horizontal, 18 * s).frame(minHeight: 110 * s)
            }
            .background(Color(hex: 0x18242e))
            .clipShape(RoundedRectangle(cornerRadius: 40 * s))
            .overlay(RoundedRectangle(cornerRadius: 40 * s).stroke(Color(hex: 0x233543), lineWidth: 2 * s))
            .padding(.horizontal, 40 * s).padding(.top, 40 * s)
            (Text("The gift is visible on your profile. ").foregroundStyle(Color(hex: 0xaec0d0)) + Text("Hide >").foregroundStyle(Color(hex: 0x58c4ff)))
                .font(.system(size: 26 * s)).padding(.top, 33 * s).padding(.bottom, 48 * s)
            Button { closed = true } label: {
                Text("OK").font(.system(size: 27 * s, weight: .medium)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 78 * s)
                    .background(Color(hex: 0x00aff6), in: Capsule()).overlay(Capsule().stroke(Color.cyan.opacity(0.75), lineWidth: 1))
            }.padding(.horizontal, 40 * s).padding(.bottom, 28 * s)
        }
    }
    private func infoRow<Content: View>(_ label: String, scale s: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Text(label).padding(.leading, 18 * s).frame(width: 166 * s, alignment: .leading)
            Rectangle().fill(Color(hex: 0x233543)).frame(width: 2 * s)
            content().frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 20 * s)
        }.font(.system(size: 26 * s)).foregroundStyle(.white).frame(height: 80 * s)
            .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x233543)).frame(height: 2 * s) }
    }
    private func attribute(_ title: String, rarity: String, scale s: CGFloat) -> some View {
        HStack(spacing: 10 * s) {
            Text(title)
            Text(rarity).font(.system(size: 23 * s)).foregroundStyle(telegramBlue)
                .padding(.horizontal, 10 * s).padding(.vertical, 3 * s).background(telegramBlue.opacity(0.2), in: Capsule())
        }
    }
    private var recipientPicker: some View {
        VStack(spacing: 22) {
            sheetHeader("Transfer Gift") { model.showRecipients = false }
            Text("Choose a Recipient").font(.system(size: 23, weight: .semibold))
            Button {} label: {
                HStack(spacing: 12) {
                    Text("M").font(.title2.weight(.medium)).frame(width: 44, height: 44).background(telegramBlue.opacity(0.25), in: Circle())
                    VStack(alignment: .leading, spacing: 4) { Text("Mira").font(.headline); Text("@mira_example · sample recipient").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(telegramBlue)
                }.foregroundStyle(.white).padding(14).background(Color(hex: 0x20313e), in: RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain)
            Button {
                model.showRecipients = false
                Task { try? await Task.sleep(for: .seconds(0.4)); await model.begin(.transfer(giftID: "nail-4465", recipientID: DemoGiftService.recipient.id)) }
            } label: { primaryLabel("Continue") }.accessibilityIdentifier("confirmRecipient").overlay { DemoTap(visible: model.tapTarget == "recipient") }
            Text("Offline demo · real bracelet untouched").font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }.padding(20).padding(.top, 10).background(pageBackground)
    }
    private var saleOptions: some View {
        VStack(spacing: 19) {
            sheetHeader("Purchase Offers") { model.showSaleOptions = false }
            NailBraceletAnimation().frame(width: 105, height: 105)
            Text("Nail Bracelet #4465").font(.system(size: 20, weight: .semibold))
            Text("Mira offers ★ 4,800").font(.system(size: 16))
            Text("Sample offer · not a real offer on your gift").font(.system(size: 12)).foregroundStyle(.secondary)
            Button {
                model.showSaleOptions = false
                Task { try? await Task.sleep(for: .seconds(0.4)); await model.begin(.acceptOffer(offerID: "sample-offer-1")) }
            } label: { primaryLabel("Review Offer") }.accessibilityIdentifier("reviewOffer")
            Spacer(minLength: 0)
        }.padding(20).padding(.top, 10).background(pageBackground)
    }
}

struct TransferGiftIcon: View {
    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 44
            ZStack(alignment: .bottomTrailing) {
                Path { path in
                    path.move(to: CGPoint(x: 4*scale, y: 13*scale)); path.addLine(to: CGPoint(x: 12*scale,y:3*scale)); path.addLine(to: CGPoint(x:32*scale,y:3*scale)); path.addLine(to: CGPoint(x:40*scale,y:13*scale)); path.addLine(to: CGPoint(x:22*scale,y:39*scale)); path.closeSubpath()
                    path.move(to: CGPoint(x:4*scale,y:13*scale)); path.addLine(to: CGPoint(x:40*scale,y:13*scale))
                    path.move(to: CGPoint(x:12*scale,y:3*scale)); path.addLine(to: CGPoint(x:17*scale,y:13*scale)); path.addLine(to: CGPoint(x:22*scale,y:39*scale))
                    path.move(to: CGPoint(x:32*scale,y:3*scale)); path.addLine(to: CGPoint(x:27*scale,y:13*scale)); path.addLine(to: CGPoint(x:22*scale,y:39*scale))
                }.stroke(.white, lineWidth: 2.5*scale)
                Image(systemName: "arrow.right.circle.fill").font(.system(size: 19*scale)).foregroundStyle(.white).background(Color(hex: 0xce7b50), in: Circle()).offset(x: 2*scale,y:1*scale)
            }
        }
    }
}

struct PepperBackdrop: View {
    private let points: [(CGFloat, CGFloat)] = [(0.08,0.04),(0.36,0.03),(0.65,0.03),(0.91,0.08),(0.19,0.12),(0.48,0.12),(0.77,0.17),(0.04,0.32),(0.32,0.22),(0.62,0.29),(0.94,0.32),(0.17,0.43),(0.45,0.47),(0.74,0.45),(0.05,0.62),(0.33,0.60),(0.64,0.65),(0.91,0.58)]
    var body: some View {
        GeometryReader { geometry in
            ForEach(points.indices, id: \.self) { index in
                Image("PepperPattern").resizable().renderingMode(.template)
                    .foregroundStyle(Color(hex: 0x9b0526).opacity(0.21))
                    .frame(width: geometry.size.width * 0.065, height: geometry.size.width * 0.065)
                    .position(x: geometry.size.width * points[index].0, y: geometry.size.height * points[index].1)
            }
        }.accessibilityHidden(true)
    }
}

struct NailBraceletAnimation: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true
        let animation = LottieAnimationView(animation: LottieAnimation.named("NailBracelet"), configuration: LottieConfiguration(renderingEngine: .mainThread))
        animation.translatesAutoresizingMaskIntoConstraints = false
        animation.contentMode = .scaleAspectFit
        animation.loopMode = .loop
        animation.backgroundBehavior = .pauseAndRestore
        container.addSubview(animation)
        NSLayoutConstraint.activate([
            animation.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animation.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animation.topAnchor.constraint(equalTo: container.topAnchor),
            animation.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        animation.play()
        return container
    }
    func updateUIView(_ view: UIView, context: Context) {}
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 140, height: proposal.height ?? 140)
    }
}

struct LockSettingsView: View {
    @ObservedObject var model: GiftLockModel
    var body: some View {
        VStack(spacing: 20) {
            sheetHeader("Gift Lock") { model.showSettings = false }
            Image(systemName: "lock.shield.fill").font(.system(size: 43)).foregroundStyle(telegramBlue)
            Text("A password before gifts leave.").font(.system(size: 20, weight: .semibold))
            Text("Require your 2-Step Verification password for\ntransfers and accepted purchase offers.").font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button {
                model.showSettings = false
                Task { try? await Task.sleep(for: .seconds(0.4)); await model.begin(.setLock(enabled: !model.snapshot.locked)) }
            } label: {
                HStack {
                    Text("Gift Lock").font(.system(size: 17)).foregroundStyle(.white)
                    Spacer()
                    ZStack(alignment: model.snapshot.locked ? .trailing : .leading) {
                        Capsule().fill(model.snapshot.locked ? telegramBlue : Color(hex: 0x243544))
                        Circle().fill(model.snapshot.locked ? .white : Color(hex: 0x18242e))
                            .frame(width: 25, height: 25).padding(3)
                    }.frame(width: 51, height: 31)
                }.padding(16).background(Color(hex: 0x20313e), in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Gift Lock").accessibilityValue(model.snapshot.locked ? "On" : "Off")
            .accessibilityIdentifier("toggleGiftLock")
            .animation(.easeInOut(duration: 0.22), value: model.snapshot.locked)
            .overlay(alignment: .trailing) { DemoTap(visible: model.tapTarget == "lockToggle").padding(.trailing, 23) }
            Text("Turning Gift Lock off also requires your password.").font(.caption).foregroundStyle(.secondary)
            Text("Offline prototype · no Telegram account connection").font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }.padding(20).padding(.top, 10).background(pageBackground)
    }
}

struct GiftReviewSheet: View {
    @ObservedObject var model: GiftLockModel
    let review: GiftReview
    @FocusState private var passwordFocused: Bool
    private var enabled: Bool { if case .setLock(let value) = review.intent { return value }; return false }
    private var title: String { review.isPolicy ? (enabled ? "Enable Gift Lock" : "Turn Off Gift Lock") : review.isSale ? "Accept Offer" : "Transfer Gift" }
    var body: some View {
        VStack(spacing: 0) {
            sheetHeader(model.receipt != nil ? "Authorization Complete" : model.enteringPassword ? "Password" : title) { passwordFocused = false; model.cancel() }
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 18) {
                    if let receipt = model.receipt { success(receipt) }
                    else if model.enteringPassword { authorization }
                    else { reviewContent }
                }.padding(.horizontal, 20).padding(.vertical, 8)
            }.scrollDismissesKeyboard(.interactively)
        }
        .background(pageBackground)
        .safeAreaInset(edge: .bottom) {
            if model.receipt == nil {
                VStack(spacing: 10) {
                    Button {
                        Task {
                            if model.enteringPassword { await model.commit() } else { await model.proceed() }
                            passwordFocused = false
                        }
                    } label: { primaryLabel(model.enteringPassword ? "Authorize & \(title)" : review.requiresPassword ? "Continue with Password" : "Confirm") }
                        .disabled(model.busy || (model.enteringPassword && model.password.isEmpty))
                        .opacity(model.enteringPassword && model.password.isEmpty ? 0.45 : 1)
                        .accessibilityIdentifier("authorizeAction").overlay { DemoTap(visible: model.tapTarget == "authorize") }
                    Text("Offline demo · real bracelet untouched").font(.system(size: 10)).foregroundStyle(.secondary)
                }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8).background(pageBackground)
            }
        }
        .onDisappear { model.password = "" }
    }
    private var reviewContent: some View {
        VStack(spacing: 16) {
            if review.gift != nil {
                NailBraceletAnimation().frame(width: 115, height: 115)
                Text("Nail Bracelet #4465").font(.system(size: 22, weight: .semibold))
                Text("Rose Gold").font(.system(size: 15)).foregroundStyle(.secondary)
            } else {
                Image(systemName: enabled ? "lock.shield.fill" : "lock.open.fill").font(.system(size: 42)).foregroundStyle(telegramBlue).padding(12)
                Text(enabled ? "Enable Gift Lock?" : "Turn off Gift Lock?").font(.system(size: 21, weight: .semibold))
            }
            if let recipient = review.recipient {
                VStack(spacing: 0) {
                    row(review.isSale ? "Buyer" : "Recipient", recipient.name + " · " + recipient.username)
                    Divider().overlay(Color(hex: 0x2a3c4b))
                    row(review.isSale ? "Offer" : "Transfer fee", review.isSale ? "★ " + review.grossStars.formatted() : "Free · demo")
                    if review.isSale { Divider().overlay(Color(hex: 0x2a3c4b)); row("Sample fee", "− ★ " + review.feeStars.formatted()) }
                }.background(Color(hex: 0x20313e), in: RoundedRectangle(cornerRadius: 14))
                HStack { Text("You receive"); Spacer(); Text("★ " + review.netStars.formatted()).fontWeight(.semibold) }
                    .font(.system(size: 19)).padding(16).background(Color(hex: review.isSale ? 0x163c34 : 0x30313a), in: RoundedRectangle(cornerRadius: 14))
                Text(review.isSale ? "Sample sale · authorization applies only to this offer." : "This is a gift transfer, not a sale.").font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                Text(enabled ? "Require fresh authorization for outgoing gifts." : "Gifts will no longer require a password in this demo.").font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }
    private var authorization: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill").font(.system(size: 37)).foregroundStyle(telegramBlue).padding(.top, 6)
            Text("Enter Your Password").font(.system(size: 22, weight: .semibold))
            Text("Confirm with your 2-Step Verification password.").font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            SecureField("Password", text: $model.password)
                .textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
                .font(.system(size: 17)).padding(16).background(Color(hex: 0x20313e), in: RoundedRectangle(cornerRadius: 13))
                .focused($passwordFocused).submitLabel(.done)
                .onSubmit { Task { await model.commit(); passwordFocused = false } }.accessibilityIdentifier("giftPassword")
            if !model.error.isEmpty { Text(model.error).font(.system(size: 12)).foregroundStyle(.red).multilineTextAlignment(.center).accessibilityIdentifier("authorizationError") }
            VStack(spacing: 6) {
                Text(review.isPolicy ? title : "Nail Bracelet #4465 → @mira_example").font(.system(size: 13, weight: .medium))
                if !review.isPolicy { Text("You receive ★ " + review.netStars.formatted()).font(.system(size: 13)).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity).padding(12).background(Color(hex: 0x20313e), in: RoundedRectangle(cornerRadius: 13))
            Text("Demo only: gift-demo-2026\nNever enter your real Telegram password here.").font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
    private func success(_ receipt: GiftReceipt) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.shield.fill").font(.system(size: 51)).foregroundStyle(.green).padding(.top, 8)
            Text(review.isSale ? "Offer authorized" : review.isPolicy ? receipt.title : "Transfer authorized").font(.system(size: 23, weight: .semibold))
            Text("Completed in the offline demo only.\nYour real bracelet is unchanged.").font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(3)
            Label(model.snapshot.locked ? "Gift Lock stays on" : "Gift Lock is off", systemImage: "lock.fill").font(.system(size: 12)).foregroundStyle(.secondary)
            Button { model.cancel() } label: { primaryLabel("Done") }.accessibilityIdentifier("doneAction").overlay { DemoTap(visible: model.tapTarget == "done") }
        }
    }
    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value) }.font(.system(size: 14)).padding(.horizontal, 16).padding(.vertical, 13)
    }
}

private func primaryLabel(_ title: String) -> some View {
    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 49)
        .background(Color(hex: 0x00aff6), in: RoundedRectangle(cornerRadius: 13))
}
private func sheetHeader(_ title: String, close: @escaping () -> Void) -> some View {
    HStack {
        Color.clear.frame(width: 30, height: 30)
        Spacer()
        Text(title).font(.system(size: 15, weight: .semibold))
        Spacer()
        Button(action: close) { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: 0xa8b6c1)).frame(width: 30, height: 30).background(Color(hex: 0x293c4b), in: Circle()) }.accessibilityLabel("Cancel")
    }
}
struct DemoTap: View {
    let visible: Bool
    var body: some View {
        Circle().fill(.white.opacity(0.2)).overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 3)).frame(width: 38, height: 38)
            .scaleEffect(visible ? 1.15 : 0.7).opacity(visible ? 1 : 0).animation(.easeOut(duration: 0.2), value: visible).allowsHitTesting(false).accessibilityHidden(true)
    }
}
private extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}
