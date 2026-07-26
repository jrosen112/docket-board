import SwiftUI

struct ItemDatesContent: View {
    @Environment(\.docketSurfacePalette) private var palette

    let item: any SharedListItem
    let isEditing: Bool
    let accent: Color
    @Binding var draft: ItemDraft
    let onEdit: () -> Void

    var body: some View {
        if isEditing {
            editor
        } else {
            timeline
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            plannedDateEditor

            Divider().opacity(0.5)

            completionHistoryEditor
        }
    }

    @ViewBuilder
    private var plannedDateEditor: some View {
        if draft.plannedDate != nil {
            VStack(alignment: .leading, spacing: 10) {
                Label("Planned", systemImage: "calendar.badge.clock")
                    .font(DocketDetailTheme.Fact.labelFont)
                    .foregroundStyle(palette.secondaryText)

                DatePicker(
                    "Planned date",
                    selection: plannedDateBinding,
                    displayedComponents: plannedDateComponents
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(accent)

                Toggle("Include a time", isOn: plannedDateHasTimeBinding)
                    .font(DocketDetailTheme.Fact.labelFont)
                    .tint(accent)

                Button(role: .destructive) {
                    draft.removePlannedDate()
                } label: {
                    Label("Remove planned date", systemImage: "calendar.badge.minus")
                }
                .font(DocketDetailTheme.Fact.labelFont)
            }
        } else {
            Button {
                draft.addPlannedDate()
            } label: {
                Label("Add planned date", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(DocketDetailTheme.Fact.valueFont)
            .foregroundStyle(accent)
            .buttonStyle(.plain)
        }
    }

    private var completionHistoryEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(DocketDetailTheme.Fact.labelFont)
                    .foregroundStyle(palette.secondaryText)

                Spacer()

                Button {
                    draft.logCompletion()
                } label: {
                    Label(item.category.logCompletionLabel, systemImage: "plus.circle.fill")
                }
                .font(DocketDetailTheme.Fact.labelFont)
                .foregroundStyle(accent)
                .buttonStyle(.plain)
            }

            if draft.completionDates.isEmpty {
                Text("No dates logged yet.")
                    .font(DocketDetailTheme.Empty.font)
                    .foregroundStyle(palette.mutedText)
            } else {
                ForEach(Array(draft.completionDates.indices), id: \.self) { index in
                    HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DocketDetailTheme.Fact.symbolFont)
                            .foregroundStyle(accent)
                            .frame(width: DocketDetailTheme.Fact.symbolWidth)

                        Text(item.category.completionLabel)
                            .font(DocketDetailTheme.Fact.labelFont)
                            .foregroundStyle(palette.secondaryText)

                        Spacer(minLength: 8)

                        DatePicker(
                            "\(item.category.completionLabel) date",
                            selection: completionDateBinding(at: index),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(accent)

                        Button(role: .destructive) {
                            draft.completionDates.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(
                            "Remove \(item.category.completionLabel.lowercased()) date"
                        )
                    }
                }
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
                    Image(systemName: "calendar.badge.clock")
                        .font(DocketDetailTheme.Fact.symbolFont)
                        .foregroundStyle(accent)
                        .frame(width: DocketDetailTheme.Fact.symbolWidth)

                    Text("Planned")
                        .font(DocketDetailTheme.Fact.labelFont)
                        .foregroundStyle(palette.secondaryText)

                    Spacer(minLength: DocketDetailTheme.Fact.valueMinimumSpacing)

                    Text(plannedDateText)
                        .font(DocketDetailTheme.Fact.valueFont)
                        .foregroundStyle(
                            item.plannedDate == nil
                                ? palette.mutedText
                                : palette.primaryText
                        )
                        .multilineTextAlignment(.trailing)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.mutedText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().opacity(0.5)

            HStack(spacing: 12) {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(DocketDetailTheme.Fact.labelFont)
                    .foregroundStyle(palette.secondaryText)

                Spacer()

                Button("Edit", action: onEdit)
                    .font(DocketDetailTheme.Fact.labelFont)
                    .foregroundStyle(accent)
                    .buttonStyle(.plain)
            }

            if item.completionDates.isEmpty {
                Text("No dates logged yet.")
                    .font(DocketDetailTheme.Empty.font)
                    .foregroundStyle(palette.mutedText)
            } else {
                ForEach(
                    Array(item.completionDates.sorted(by: >).enumerated()),
                    id: \.offset
                ) { _, date in
                    HStack(spacing: DocketDetailTheme.Fact.rowSpacing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DocketDetailTheme.Fact.symbolFont)
                            .foregroundStyle(accent)
                            .frame(width: DocketDetailTheme.Fact.symbolWidth)

                        Text(item.category.completionLabel)
                            .font(DocketDetailTheme.Fact.labelFont)
                            .foregroundStyle(palette.secondaryText)

                        Spacer(minLength: DocketDetailTheme.Fact.valueMinimumSpacing)

                        Text(
                            date,
                            format: .dateTime.month(.abbreviated).day().year()
                        )
                        .font(DocketDetailTheme.Fact.valueFont)
                        .foregroundStyle(palette.primaryText)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onEdit)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private var plannedDateBinding: Binding<Date> {
        Binding(
            get: { draft.plannedDate ?? .now },
            set: { draft.plannedDate = $0 }
        )
    }

    private var plannedDateHasTimeBinding: Binding<Bool> {
        Binding(
            get: { draft.plannedDateHasTime },
            set: { includesTime in
                draft.plannedDateHasTime = includesTime
                guard includesTime, let plannedDate = draft.plannedDate else { return }
                let components = Calendar.current.dateComponents(
                    [.hour, .minute],
                    from: plannedDate
                )
                guard components.hour == 0, components.minute == 0 else { return }
                draft.plannedDate =
                    Calendar.current.date(
                        bySettingHour: 19,
                        minute: 0,
                        second: 0,
                        of: plannedDate
                    ) ?? plannedDate
            }
        )
    }

    private var plannedDateComponents: DatePickerComponents {
        draft.plannedDateHasTime ? [.date, .hourAndMinute] : .date
    }

    private func completionDateBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: { draft.completionDates[index] },
            set: { draft.completionDates[index] = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var plannedDateText: String {
        guard let plannedDate = item.plannedDate else { return "Add date" }
        if item.plannedDateHasTime {
            return plannedDate.formatted(date: .abbreviated, time: .shortened)
        }
        return plannedDate.formatted(date: .abbreviated, time: .omitted)
    }
}
