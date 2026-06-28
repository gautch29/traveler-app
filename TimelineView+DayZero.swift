import SwiftUI

extension TimelineView {
    @ViewBuilder
    func dayZeroView(_ trip: Trip) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 100)
                
                VStack(spacing: 8) {
                    Text("Welcome to")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(trip.tripName)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Dates: \(formatDateStringShort(trip.startDate)) to \(formatDateStringShort(trip.endDate))")
                            .fontWeight(.semibold)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Travelers: \(trip.users.joined(separator: ", "))")
                            .fontWeight(.semibold)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emergency Contact Info")
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            ForEach(trip.emergencyInfo.numbers) { item in
                                HStack {
                                    Text("\(item.label):")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    if let url = URL(string: "tel://\(item.number.replacingOccurrences(of: " ", with: ""))") {
                                        Link(item.number, destination: url)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.accentColor)
                                    } else {
                                        Text(item.number)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .font(.subheadline)
                            }
                            
                            if !trip.emergencyInfo.notes.isEmpty {
                                Text(trip.emergencyInfo.notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassStyle(cornerRadius: 20, fillOpacity: 0.03, borderOpacity: 0.45)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trip Steps Summary")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 6)
                    
                    ForEach(Array(trip.steps.enumerated()), id: \.element.id) { index, step in
                        Button {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                activeDayIndex = index + 1
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(step.type == .stay ? Color.purple : (step.type == .flight ? Color.blue : (step.type == .train ? Color.orange : Color.green)))
                                    .clipShape(Circle())
                                
                                Text(step.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Text(formatDateStringShort(step.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .contentShape(Rectangle())
                            .liquidGlassStyle(cornerRadius: 10, fillOpacity: 0.015, borderOpacity: 0.25)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: 50)
            }
        }
    }
}
