//
//  GapFinder.swift
//  FocusBlox
//
//  Shared between iOS and macOS for finding free time slots
//

import Foundation

// MARK: - Time Slot

/// Represents a free time slot in the calendar
struct TimeSlot: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
}

// MARK: - Gap Finder

/// Finds free time slots between calendar events for focus blocks
struct GapFinder {
    let events: [CalendarEvent]
    let focusBlocks: [FocusBlock]
    let scheduledTasks: [(start: Date, end: Date)]
    let date: Date

    init(events: [CalendarEvent], focusBlocks: [FocusBlock], scheduledTasks: [(start: Date, end: Date)] = [], date: Date) {
        self.events = events
        self.focusBlocks = focusBlocks
        self.scheduledTasks = scheduledTasks
        self.date = date
    }

    private let startHour = 6
    private let endHour = 22

    /// Find free slots within the min/max duration range
    func findFreeSlots(minMinutes: Int = 30, maxMinutes: Int = 60) -> [TimeSlot] {
        let calendar = Calendar.current

        // Get day boundaries
        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startComponents.hour = startHour
        startComponents.minute = 0
        let dayStart = calendar.date(from: startComponents) ?? date

        var endComponents = calendar.dateComponents([.year, .month, .day], from: date)
        endComponents.hour = endHour
        endComponents.minute = 0
        let dayEnd = calendar.date(from: endComponents) ?? date

        // Collect all busy periods
        var busyPeriods: [(start: Date, end: Date)] = []

        for event in events where !event.isAllDay && !event.isFocusBlock {
            busyPeriods.append((event.startDate, event.endDate))
        }

        for block in focusBlocks {
            busyPeriods.append((block.startDate, block.endDate))
        }

        for task in scheduledTasks {
            busyPeriods.append((task.start, task.end))
        }

        // Sort by start time
        busyPeriods.sort { $0.start < $1.start }

        // Find gaps
        var gaps: [TimeSlot] = []
        // Start from current time for today, not day start (06:00)
        // This prevents showing past time slots
        let now = Date()
        var currentTime = Calendar.current.isDate(now, inSameDayAs: date) ? max(dayStart, now) : dayStart

        for period in busyPeriods {
            // Skip periods outside our time range
            if period.end <= dayStart || period.start >= dayEnd {
                continue
            }

            // Clamp to day boundaries
            let periodStart = max(period.start, dayStart)

            // Found a gap before this period
            if currentTime < periodStart {
                let gapDuration = Int(periodStart.timeIntervalSince(currentTime) / 60)
                if gapDuration >= minMinutes {
                    // If gap is larger than max, create a slot at the start
                    let slotEnd: Date
                    if gapDuration > maxMinutes {
                        slotEnd = currentTime.addingTimeInterval(Double(maxMinutes) * 60)
                    } else {
                        slotEnd = periodStart
                    }
                    gaps.append(TimeSlot(startDate: currentTime, endDate: slotEnd))
                }
            }

            // Move current time to end of this period
            currentTime = max(currentTime, min(period.end, dayEnd))
        }

        // Check for gap at the end of the day
        if currentTime < dayEnd {
            let gapDuration = Int(dayEnd.timeIntervalSince(currentTime) / 60)
            if gapDuration >= minMinutes {
                let slotEnd: Date
                if gapDuration > maxMinutes {
                    slotEnd = currentTime.addingTimeInterval(Double(maxMinutes) * 60)
                } else {
                    slotEnd = dayEnd
                }
                gaps.append(TimeSlot(startDate: currentTime, endDate: slotEnd))
            }
        }

        return gaps
    }
}
