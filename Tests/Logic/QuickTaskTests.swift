// QuickTaskTests.swift: Phase 8d. The web has no test for QuickTaskCard
// (it lives inside app/classes/page.tsx), so these pin what its code does:
// the day each card starts on, when Add is allowed, and the title it files.
// Run: scripts/test-logic.sh. Kelvin does not type this file.

import Foundation
import Testing
@testable import CPLogic

@Suite struct QuickTaskTests {
    @Test func remindersStartTomorrowAndAssignmentsInThreeDays() {
        #expect(quickTaskDaysAhead(.reminder) == 1)
        #expect(quickTaskDaysAhead(.assignment) == 3)
    }

    @Test func aReminderNeedsItsOwnWords() {
        #expect(!quickTaskCanSave(.reminder, title: ""))
        #expect(!quickTaskCanSave(.reminder, title: "  \n\t "))
        #expect(quickTaskCanSave(.reminder, title: "Bring goggles"))
    }

    @Test func anAssignmentCanBeAddedBlank() {
        #expect(quickTaskCanSave(.assignment, title: ""))
        #expect(quickTaskCanSave(.assignment, title: "   "))
        #expect(quickTaskCanSave(.assignment, title: "Lab 3"))
    }

    @Test func typedWordsWinTrimmed() {
        #expect(quickTaskTitle(.assignment, title: "  Lab 3 write-up ", className: "Chemistry",
                               type: .quiz) == "Lab 3 write-up")
        #expect(quickTaskTitle(.reminder, title: "\tBring goggles\n", className: "Chemistry",
                               type: .assignment) == "Bring goggles")
    }

    @Test func aBlankAssignmentIsNamedAfterItsClassAndKind() {
        // The web's `${className} ${type}`, with the type's lowercase id.
        #expect(quickTaskTitle(.assignment, title: "", className: "Chemistry",
                               type: .quiz) == "Chemistry quiz")
        #expect(quickTaskTitle(.assignment, title: "  ", className: "Biology",
                               type: .exam) == "Biology exam")
        #expect(quickTaskTitle(.assignment, title: "", className: "Calculus III",
                               type: .assignment) == "Calculus III assignment")
        // A note with no class: its header's name, as on the web.
        #expect(quickTaskTitle(.assignment, title: "", className: "Quick note",
                               type: .assignment) == "Quick note assignment")
    }

    @Test func aBlankReminderFallsBackToReminder() {
        // Never filed (Add stays off), but the web's fallback is kept.
        #expect(quickTaskTitle(.reminder, title: " ", className: "Chemistry",
                               type: .exam) == "Reminder")
    }

    @Test func theTypesAreTheWebsInItsOrder() {
        #expect(QuickTaskType.allCases.map(\.rawValue) == ["assignment", "quiz", "exam"])
        #expect(QuickTaskType.allCases.map(\.label) == ["Assignment", "Quiz", "Exam"])
    }

    @Test func aModeIsItsOwnId() {
        #expect(QuickTaskMode.reminder.id == .reminder)
        #expect(QuickTaskMode.assignment.id != QuickTaskMode.reminder.id)
    }
}
