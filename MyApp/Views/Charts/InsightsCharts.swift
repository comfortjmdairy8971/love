import SwiftUI
import Charts

// Swift Charts has no UIKit API, so these small views are embedded with `UIHostingController`.

struct WeekBucket: Identifiable {
    let weekStart: Date
    let category: ActivityCategory
    let minutes: Int
    var id: String { "\(weekStart.timeIntervalSince1970)-\(category.rawValue)" }
    var hours: Double { Double(minutes) / 60 }
}

struct CategoryShare: Identifiable {
    let category: ActivityCategory
    let minutes: Int
    var id: String { category.rawValue }
}

struct WeekdayTotal: Identifiable {
    let weekday: Int
    let symbol: String
    let minutes: Int
    var id: Int { weekday }
    var hours: Double { Double(minutes) / 60 }
}

extension ActivityCategory {
    var chartColor: Color { Color(uiColor: color) }
}

// MARK: - Weekly Category Distribution
struct WeeklyBreakdownChart: View {
    var buckets: [WeekBucket] = []
    var weeks: Int = 8

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                y: .value("Hours", bucket.hours)
            )
            .foregroundStyle(by: .value("Category", bucket.category.title))
            .cornerRadius(3)
        }
        .chartForegroundStyleScale(
            domain: ActivityCategory.allCases.map(\.title),
            range: ActivityCategory.allCases.map(\.chartColor)
        )
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: weeks <= 4 ? 1 : 2)) {
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxisLabel("hours")
    }
}

// MARK: - Category Balance Donut
struct CategoryBalanceChart: View {
    var shares: [CategoryShare] = []
    var totalMinutes: Int = 0

    var body: some View {
        Chart(shares) { share in
            SectorMark(
                angle: .value("Minutes", share.minutes),
                innerRadius: .ratio(0.62),
                angularInset: 2
            )
            .cornerRadius(4)
            .foregroundStyle(share.category.chartColor)
        }
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text(formatDuration(minutes: totalMinutes))
                    .font(.title3.weight(.bold))
                Text("total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Peak Connection Days
struct WeekdayPeakChart: View {
    var totals: [WeekdayTotal] = []
    var bestWeekday: Int?

    var body: some View {
        Chart(totals) { day in
            BarMark(
                x: .value("Day", day.symbol),
                y: .value("Hours", day.hours)
            )
            .cornerRadius(4)
            .foregroundStyle(day.weekday == bestWeekday ? Color(uiColor: .brandAccent) : Color(uiColor: .brandAccent).opacity(0.3))
        }
        .chartYAxisLabel("hours")
    }
}
