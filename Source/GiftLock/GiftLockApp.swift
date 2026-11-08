import SwiftUI

private let telegramBlue = Color(red: 0.04, green: 0.51, blue: 0.91)
private let pageBackground = Color(uiColor: .systemGroupedBackground)

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
    func reset() async {
        cancel(); service = DemoGiftService(); await refresh()
    }
    func runTour() async {
        guard !tourRunning else { return }
        tourRunning = true
        await reset()
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        func tap(_ target: String) async {
            tapTarget = target; await pause(0.28); tapTarget = nil
        }
        tourCaption = ""
        await pause(1)
        await tap("settings")
        showSettings = true
        await pause(1.8)
        showSettings = false
        await pause(0.45)
        await tap("offer")
        await begin(.acceptOffer(offerID: "sample-offer-1"))
        await pause(2)
        await tap("authorize")
        await proceed()
        await pause(0.8)
        password = "incorrect-demo-password"
        await pause(0.7)
        await tap("authorize")
        await commit()
        await pause(1.6)
        password = DemoGiftService.samplePassword
        await pause(0.7)
        await tap("authorize")
        await commit()
        await pause(2)
        await tap("done")
        cancel()
        await pause(0.6)
        await tap("collection")
        showCollection = true
        await pause(1.2)
        await tap("crystal-381")
        showCollection = false
        await pause(0.4)
        await begin(.transfer(giftID: "crystal-381", recipientID: DemoGiftService.recipient.id))
        await pause(2)
        await tap("authorize")
        await proceed()
        await pause(1.4)
        await tap("cancel")
        cancel()
        await pause(1.8)
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
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { model.password = "" }
                    if phase == .background { model.cancel() }
                }
                .task {
                    await model.refresh()
                    if ProcessInfo.processInfo.arguments.contains("--demo-tour") {
                        try? await Task.sleep(for: .seconds(2))
                        await model.runTour()
                    }
                }
        }
    }
}

struct GiftsView: View {
    @ObservedObject var model: GiftLockModel
    @State private var draft = ""
    @State private var declined = false
    var body: some View {
        ZStack {
            TelegramWallpaper().ignoresSafeArea()
            VStack(spacing: 0) {
                chatHeader
                ScrollView {
                    VStack(spacing: 14) {
                        Text("Today").font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 11).padding(.vertical, 4)
                            .background(.white.opacity(0.38), in: Capsule()).padding(.top, 18)
                        message("Hi! Is your Moon Lantern still available?", outgoing: false, time: "9:38")
                        message("Yes, you can send me an offer here.", outgoing: true, time: "9:39")
                        if model.snapshot.gifts.contains(where: { $0.id == "moon-1042" }) && !declined {
                            offerCard
                        } else if declined {
                            Text("Offer declined").font(.system(size: 13)).padding(10)
                                .background(.white.opacity(0.4), in: Capsule())
                        } else {
                            completedCard
                        }
                        Button { model.showSettings = true } label: {
                            Label(model.snapshot.locked ? "Gift Lock is on" : "Gift Lock is off", systemImage: model.snapshot.locked ? "lock.fill" : "lock.open.fill")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(Color(red: 0.18, green: 0.39, blue: 0.36))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(.white.opacity(0.42), in: Capsule())
                        }.buttonStyle(.plain).accessibilityIdentifier("giftLockSettings")
                            .overlay { tapIndicator("settings") }
                        if model.snapshot.gifts.count < 3 {
                            Text("Your other gifts are still in your collection.")
                                .font(.system(size: 12)).foregroundStyle(.black.opacity(0.55))
                        }
                        Spacer(minLength: 15)
                    }.padding(.horizontal, 13)
                }
                bottomBar
            }
        }
        .sheet(item: $model.activeReview, onDismiss: { model.cancel() }) { review in
            GiftReviewSheet(model: model, review: review)
                .presentationDetents([.height(model.receipt != nil ? 365 : model.enteringPassword ? 505 : review.isPolicy ? 360 : 575)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $model.showSettings) {
            LockSettingsView(model: model)
                .presentationDetents([.height(485)]).presentationDragIndicator(.visible).presentationCornerRadius(28)
        }
        .sheet(isPresented: $model.showCollection) {
            collectionSheet.presentationDetents([.height(420)]).presentationDragIndicator(.visible).presentationCornerRadius(28)
        }
        .alert("Couldn’t open review", isPresented: Binding(get: { !model.error.isEmpty && model.activeReview == nil }, set: { if !$0 { model.error = "" } })) {
            Button("OK") { model.error = "" }
        } message: { Text(model.error) }
    }
    private var chatHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                .frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle())
                .accessibilityLabel("Back")
            Spacer(minLength: 0)
            VStack(spacing: 1) {
                Text("Mira").font(.system(size: 16, weight: .semibold))
                Text("online").font(.system(size: 11)).foregroundStyle(telegramBlue)
            }.frame(width: 142, height: 39).background(.ultraThinMaterial, in: Capsule())
            Spacer(minLength: 0)
            Menu {
                Button("Gift Lock", systemImage: "lock.shield") { model.showSettings = true }
                Button("My Gifts", systemImage: "gift") { model.showCollection = true }
                Button("Play 25-second demo", systemImage: "play") { Task { await model.runTour() } }
                Button("Reset sample data", systemImage: "arrow.counterclockwise") { declined = false; Task { await model.reset() } }
            } label: {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(red: 0.91, green: 0.68, blue: 0.44), Color(red: 0.65, green: 0.37, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("M").font(.system(size: 18, weight: .medium)).foregroundStyle(.white)
                }.frame(width: 39, height: 39).overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
            }
        }.foregroundStyle(.black).padding(.horizontal, 15).padding(.top, 7).padding(.bottom, 5)
    }
    private func message(_ text: String, outgoing: Bool, time: String) -> some View {
        HStack {
            if outgoing { Spacer(minLength: 45) }
            VStack(alignment: .trailing, spacing: 1) {
                Text(text).font(.system(size: 15)).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 3) {
                    Text(time).font(.system(size: 10))
                    if outgoing { Image(systemName: "checkmark").font(.system(size: 9, weight: .medium)) }
                }.foregroundStyle(.black.opacity(0.4))
            }.padding(.horizontal, 11).padding(.top, 8).padding(.bottom, 5)
                .background(outgoing ? Color(red: 0.87, green: 0.97, blue: 0.85) : Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 15))
                .frame(maxWidth: 275, alignment: outgoing ? .trailing : .leading)
            if !outgoing { Spacer(minLength: 45) }
        }
    }
    private var offerCard: some View {
        VStack(spacing: 0) {
            GiftArt(symbol: "moon.stars.fill").frame(width: 94, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 23)).padding(.top, 17)
            Text("Mira offered you **★ 4,800**\nfor your **Moon Lantern #1042**")
                .font(.system(size: 13)).multilineTextAlignment(.center).lineSpacing(3).padding(.top, 15)
            Text("Expires in 23 hours").font(.system(size: 12)).foregroundStyle(.black.opacity(0.44)).padding(.top, 12)
            HStack(spacing: 6) {
                Button("Decline") { declined = true }.frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 10))
                Button { Task { await model.begin(.acceptOffer(offerID: "sample-offer-1")) } } label: {
                    Label("Accept", systemImage: "lock.fill").frame(maxWidth: .infinity).padding(.vertical, 12)
                }.background(.white.opacity(0.60), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("reviewOffer").overlay { tapIndicator("offer") }
            }.font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(red: 0.16, green: 0.34, blue: 0.29))
                .padding(7).padding(.top, 10)
        }.frame(width: 273).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.23), lineWidth: 0.5))
            .padding(.top, 9)
    }
    private var completedCard: some View {
        VStack(spacing: 12) {
            GiftArt(symbol: "moon.stars.fill").frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 22))
            Text("Offer accepted").font(.system(size: 15, weight: .semibold))
            Text("Moon Lantern #1042 was transferred to Mira.\nYou received ★ 4,320.")
                .font(.system(size: 13)).multilineTextAlignment(.center).lineSpacing(3)
            Label("Authorized with Gift Lock", systemImage: "checkmark.shield.fill")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(Color(red: 0.10, green: 0.43, blue: 0.31))
        }.padding(20).frame(width: 273).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24)).padding(.top, 9)
    }
    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button { model.showCollection = true } label: {
                Image(systemName: "paperclip").font(.system(size: 22)).frame(width: 43, height: 43)
                    .background(.ultraThinMaterial, in: Circle())
            }.accessibilityLabel("My Gifts").accessibilityIdentifier("openCollection").overlay { tapIndicator("collection") }
            HStack(spacing: 8) {
                Image(systemName: "face.smiling").font(.system(size: 20)).foregroundStyle(.gray)
                TextField("Message", text: $draft).font(.system(size: 16))
                Image(systemName: "clock").font(.system(size: 18)).foregroundStyle(.gray)
            }.padding(.horizontal, 11).frame(height: 43).background(.ultraThinMaterial, in: Capsule())
            Image(systemName: "mic.fill").font(.system(size: 21)).frame(width: 37, height: 43)
        }.foregroundStyle(telegramBlue).padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 4)
    }
    private var collectionSheet: some View {
        VStack(spacing: 20) {
            sheetHeader("My Gifts") { model.showCollection = false }
            HStack {
                Text("\(model.snapshot.gifts.count) gifts · sample account").font(.system(size: 13)).foregroundStyle(.secondary)
                Spacer()
                Label(model.snapshot.stars.formatted(), systemImage: "star.fill").font(.system(size: 13, weight: .medium)).foregroundStyle(.orange)
            }
            HStack(spacing: 12) {
                ForEach(model.snapshot.gifts) { gift in
                    Button {
                        model.showCollection = false
                        Task { try? await Task.sleep(for: .seconds(0.4)); await model.begin(.transfer(giftID: gift.id, recipientID: DemoGiftService.recipient.id)) }
                    } label: {
                        VStack(spacing: 8) {
                            GiftArt(symbol: gift.symbol).frame(height: 108).clipShape(RoundedRectangle(cornerRadius: 13))
                            Text(gift.title).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                            Text(gift.number).font(.system(size: 12)).foregroundStyle(.secondary)
                        }.padding(8).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain).overlay { tapIndicator(gift.id) }
                }
            }
            Text("Select a gift to transfer to Mira").font(.system(size: 13)).foregroundStyle(.secondary)
            Text("Prototype · fictional gifts and account").font(.system(size: 10)).foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }.padding(18).padding(.top, 8).background(pageBackground)
    }
    private func tapIndicator(_ target: String) -> some View {
        DemoTap(visible: model.tapTarget == target)
    }
}

struct TelegramWallpaper: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.76, green: 0.90, blue: 0.78), Color(red: 0.77, green: 0.85, blue: 0.96), Color(red: 0.70, green: 0.84, blue: 0.94)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image("ChatPattern").resizable().renderingMode(.template)
                    .scaledToFill().frame(width: geometry.size.width, height: geometry.size.height)
                    .foregroundStyle(Color(red: 0.28, green: 0.58, blue: 0.64).opacity(0.18)).clipped()
            }
        }.accessibilityHidden(true)
    }
}

struct LockSettingsView: View {
    @ObservedObject var model: GiftLockModel
    var body: some View {
        VStack(spacing: 20) {
            sheetHeader("Gift Lock") { model.showSettings = false }
            Image(systemName: "lock.shield.fill").font(.system(size: 43)).foregroundStyle(telegramBlue).padding(.top, 6)
            Text("A password before gifts leave.").font(.system(size: 20, weight: .semibold))
            Text("Use your 2-Step Verification password for\ntransfers and accepted purchase offers.")
                .font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(3)
            Button {
                model.showSettings = false
                Task { try? await Task.sleep(for: .seconds(0.4)); await model.begin(.setLock(enabled: !model.snapshot.locked)) }
            } label: {
                HStack {
                    Text("Gift Lock").foregroundStyle(.primary)
                    Spacer()
                    Text(model.snapshot.locked ? "On" : "Off").foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
                }.font(.system(size: 16)).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityIdentifier("toggleGiftLock")
            Text("Turning Gift Lock off also requires your password.")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Prototype · sample data").font(.system(size: 10)).foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }.padding(18).padding(.top, 8).frame(maxWidth: .infinity).background(pageBackground)
    }
}

struct GiftReviewSheet: View {
    @ObservedObject var model: GiftLockModel
    let review: GiftReview
    @FocusState private var passwordFocused: Bool
    private var policyEnabled: Bool { if case .setLock(let enabled) = review.intent { return enabled }; return false }
    private var actionTitle: String {
        review.isPolicy ? (policyEnabled ? "Enable Gift Lock" : "Turn Off Gift Lock") : (review.isSale ? "Accept Offer" : "Transfer Gift")
    }
    var body: some View {
        VStack(spacing: 0) {
            sheetHeader(model.receipt?.title ?? (model.enteringPassword ? "Password" : actionTitle)) {
                passwordFocused = false; model.cancel()
            }.padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 12)
                .overlay(alignment: .topTrailing) { DemoTap(visible: model.tapTarget == "cancel").frame(width: 35, height: 35).padding(.top, 24).padding(.trailing, 18) }
            ScrollView {
                VStack(spacing: 17) {
                    if let receipt = model.receipt {
                        success(receipt)
                    } else if model.enteringPassword {
                        authorization
                    } else {
                        reviewContent
                    }
                }.padding(.horizontal, 18).padding(.top, 7).padding(.bottom, 12)
            }.scrollDismissesKeyboard(.interactively)
        }
        .background(pageBackground)
        .safeAreaInset(edge: .bottom) {
            if model.receipt == nil {
                VStack(spacing: 9) {
                    Button {
                        passwordFocused = false
                        Task { if model.enteringPassword { await model.commit() } else { await model.proceed() } }
                    } label: {
                        HStack(spacing: 7) {
                            if model.busy { ProgressView().tint(.white) }
                            else { Image(systemName: "lock.fill").font(.system(size: 13)) }
                            Text(model.enteringPassword ? "Authorize & \(actionTitle)" : review.requiresPassword ? "Continue with Password" : "Confirm")
                                .font(.system(size: 16, weight: .semibold))
                        }.frame(maxWidth: .infinity).frame(height: 50)
                    }.buttonStyle(.plain).foregroundStyle(.white).background(telegramBlue, in: RoundedRectangle(cornerRadius: 12))
                        .disabled(model.busy || (model.enteringPassword && model.password.isEmpty))
                        .opacity(model.enteringPassword && model.password.isEmpty ? 0.45 : 1)
                        .accessibilityIdentifier("authorizeAction")
                        .overlay { DemoTap(visible: model.tapTarget == "authorize") }
                    Text("Prototype · sample data").font(.system(size: 10)).foregroundStyle(.tertiary)
                }.padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 8).background(pageBackground)
            }
        }
        .onDisappear { model.password = "" }
    }
    private var reviewContent: some View {
        VStack(spacing: 16) {
            if let gift = review.gift {
                GiftArt(symbol: gift.symbol).frame(width: 92, height: 92).clipShape(RoundedRectangle(cornerRadius: 23))
                Text(gift.title + " " + gift.number).font(.system(size: 20, weight: .semibold))
            } else {
                Image(systemName: policyEnabled ? "lock.shield.fill" : "lock.open.fill").font(.system(size: 40))
                    .foregroundStyle(policyEnabled ? telegramBlue : .orange).padding(.vertical, 10)
                Text(policyEnabled ? "Enable Gift Lock?" : "Turn off Gift Lock?").font(.system(size: 20, weight: .semibold))
            }
            if let peer = review.recipient {
                VStack(spacing: 0) {
                    detailRow(review.isSale ? "Buyer" : "Recipient", peer.name + " · " + peer.username)
                    Divider().padding(.leading, 16)
                    if review.isSale {
                        detailRow("Offer", "★ " + review.grossStars.formatted())
                        Divider().padding(.leading, 16)
                        detailRow("Sample fee", "− ★ " + review.feeStars.formatted())
                    } else {
                        detailRow("Transfer fee", "Free")
                    }
                }.background(.white, in: RoundedRectangle(cornerRadius: 12))
                HStack {
                    Text("You receive").font(.system(size: 15))
                    Spacer()
                    Text("★ " + review.netStars.formatted()).font(.system(size: 21, weight: .semibold))
                }.foregroundStyle(review.isSale ? Color(red: 0.13, green: 0.58, blue: 0.36) : .primary)
                    .padding(16).background(review.isSale ? Color.green.opacity(0.08) : Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                Text(review.isSale ? "The gift will be transferred after authorization." : "This is a gift transfer, not a sale.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                Text(policyEnabled ? "Require a password for outgoing gifts." : "Gifts will no longer require a password.")
                    .font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }
    private var authorization: some View {
        VStack(spacing: 17) {
            Image(systemName: "lock.fill").font(.system(size: 38)).foregroundStyle(telegramBlue)
                .frame(height: 56).padding(.top, 2)
            Text("Enter Your Password").font(.system(size: 21, weight: .semibold))
            Text("Confirm with your 2-Step Verification password.")
                .font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            SecureField("Password", text: $model.password)
                .textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
                .font(.system(size: 17)).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 12))
                .focused($passwordFocused).submitLabel(.done)
                .onSubmit { passwordFocused = false; Task { await model.commit() } }
                .accessibilityIdentifier("giftPassword")
            if !model.error.isEmpty {
                Text(model.error).font(.system(size: 12)).foregroundStyle(.red)
                    .multilineTextAlignment(.center).accessibilityIdentifier("authorizationError")
            }
            VStack(spacing: 5) {
                if let gift = review.gift, let peer = review.recipient {
                    Text(gift.title + " " + gift.number + " → " + peer.username).font(.system(size: 13, weight: .medium))
                    Text("You receive ★ " + review.netStars.formatted()).font(.system(size: 13)).foregroundStyle(.secondary)
                } else {
                    Text(actionTitle).font(.system(size: 14, weight: .medium))
                }
            }.frame(maxWidth: .infinity).padding(12).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            Text("Demo only: gift-demo-2026\nNever use your real Telegram password here.")
                .font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(2)
        }
    }
    private func success(_ receipt: GiftReceipt) -> some View {
        VStack(spacing: 17) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 50)).foregroundStyle(Color(red: 0.20, green: 0.69, blue: 0.40)).padding(.top, 8)
            Text(receipt.detail).font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(3)
            Label(model.snapshot.locked ? "Gift Lock stays on" : "Gift Lock is off", systemImage: model.snapshot.locked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Button("Done") { model.cancel() }.font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity).frame(height: 49).foregroundStyle(.white)
                .background(telegramBlue, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("doneAction").overlay { DemoTap(visible: model.tapTarget == "done") }
        }
    }
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).multilineTextAlignment(.trailing)
        }.font(.system(size: 14)).padding(.horizontal, 16).padding(.vertical, 12)
    }
}

private func sheetHeader(_ title: String, close: @escaping () -> Void) -> some View {
    HStack {
        Color.clear.frame(width: 30, height: 30)
        Spacer()
        Text(title).font(.system(size: 15, weight: .semibold))
        Spacer()
        Button(action: close) {
            Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
                .frame(width: 30, height: 30).background(.white.opacity(0.8), in: Circle())
        }.accessibilityLabel("Cancel")
    }
}

struct DemoTap: View {
    let visible: Bool
    var body: some View {
        Circle().fill(.white.opacity(0.20)).overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 3))
            .frame(width: 38, height: 38).scaleEffect(visible ? 1.15 : 0.7).opacity(visible ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: visible).allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct GiftArt: View {
    let symbol: String
    var hero = false
    private var moon: Bool { symbol == "moon.stars.fill" }
    private var blue: Bool { symbol == "diamond.fill" }
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                LinearGradient(colors: moon ? [Color(red: 0.13, green: 0.16, blue: 0.35), Color(red: 0.31, green: 0.29, blue: 0.58)] : blue ? [Color(red: 0.79, green: 0.90, blue: 1), Color(red: 0.62, green: 0.77, blue: 0.98)] : [Color(red: 1, green: 0.91, blue: 0.70), Color(red: 1, green: 0.78, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.055)).frame(width: size * 1.1).offset(x: size * 0.6, y: size * 0.3)
                Circle().stroke(.white.opacity(0.10), lineWidth: 1).frame(width: size * 0.9).offset(x: -size * 0.45, y: -size * 0.15)
                ForEach(0..<7) { index in
                    Image(systemName: "sparkle").font(.system(size: index.isMultiple(of: 2) ? 10 : 6))
                        .foregroundStyle(.white.opacity(0.5))
                        .offset(x: size * CGFloat([-0.37, 0.33, -0.24, 0.40, -0.4, 0.23, 0.08][index]),
                                y: size * CGFloat([-0.25, -0.30, 0.35, 0.20, 0.05, 0.38, -0.4][index]))
                }
                if moon {
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 9).stroke(Color(red: 0.99, green: 0.82, blue: 0.46), lineWidth: 3)
                            .frame(width: size * 0.17, height: size * 0.10).offset(y: 3)
                        ZStack {
                            RoundedRectangle(cornerRadius: size * 0.20)
                                .fill(LinearGradient(colors: [Color(red: 1, green: 0.89, blue: 0.58), Color(red: 0.95, green: 0.61, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: .orange.opacity(0.4), radius: 18)
                            RoundedRectangle(cornerRadius: size * 0.18).stroke(.white.opacity(0.45), lineWidth: 1.5).padding(5)
                            Image(systemName: "moon.stars.fill").font(.system(size: size * 0.23)).foregroundStyle(Color(red: 0.48, green: 0.31, blue: 0.17))
                        }.frame(width: size * 0.48, height: size * 0.50)
                        Capsule().fill(Color(red: 1, green: 0.8, blue: 0.4)).frame(width: size * 0.20, height: size * 0.035)
                        Capsule().fill(Color(red: 1, green: 0.8, blue: 0.4)).frame(width: 3, height: size * 0.09)
                        Image(systemName: "diamond.fill").font(.system(size: size * 0.045)).foregroundStyle(.orange)
                    }
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.48, weight: .regular))
                        .foregroundStyle(LinearGradient(colors: blue ? [.white, Color(red: 0.12, green: 0.48, blue: 0.89)] : [.white, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: (blue ? Color.blue : Color.orange).opacity(0.3), radius: 8, y: 7)
                        .rotationEffect(.degrees(blue ? -10 : 12))
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        }.accessibilityHidden(true)
    }
}
