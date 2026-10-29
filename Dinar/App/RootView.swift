import SwiftUI

/// The tab bar shell. On iOS 26 the tab bar and its bottom accessory are Liquid Glass.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("خانه", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("تراکنش‌ها", systemImage: "list.bullet.rectangle.portrait.fill", value: AppTab.transactions) {
                TransactionsView()
            }
            Tab("گزارش", systemImage: "chart.pie.fill", value: AppTab.reports) {
                ReportsView()
            }
            Tab("بودجه", systemImage: "gauge.with.needle.fill", value: AppTab.budgets) {
                BudgetsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            AddEntryAccessory()
        }
        .sheet(item: $router.editor) { request in
            EntryEditorView(request: request, unit: settings.currencyUnit)
        }
        .sheet(isPresented: $router.isShowingSettings) {
            SettingsView()
        }
    }
}

/// A glass accessory above the tab bar for the most common action: logging money.
private struct AddEntryAccessory: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: 0) {
            Button {
                router.newEntry(.expense)
            } label: {
                Label("تراکنش جدید", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            if placement != .inline {
                Divider().frame(height: 20)
                Button { router.newEntry(.income) } label: {
                    Image(systemName: EntryKind.income.symbol)
                        .frame(width: 44)
                }
                .accessibilityLabel("ثبت درآمد")
                Button { router.newEntry(.transfer) } label: {
                    Image(systemName: EntryKind.transfer.symbol)
                        .frame(width: 44)
                }
                .accessibilityLabel("انتقال بین حساب‌ها")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}
