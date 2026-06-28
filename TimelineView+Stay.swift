import SwiftUI
import MapKit

extension TimelineView {
    func staySummaryCard(_ step: Step, stay: StayStepInfo) -> some View {
        let user = store.selectedUser ?? ""
        let hotelFiles = stay.hotel?.getFiles(forUser: user) ?? []
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STAY")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple)
                    .cornerRadius(6)
                
                Spacer()
                
                if !isTimelineEditMode {
                    Button {
                        withAnimation {
                            store.selectedStep = step
                            store.selectedTab = 1
                        }
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.purple)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 4)
                }
                
                Text("\(stay.days.count) Days")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Step Title", text: binding.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .glassTextFieldStyle()
                    
                    TextField("City Name", text: Binding(
                        get: { binding.wrappedValue.stayInfo?.cityName ?? "" },
                        set: { binding.wrappedValue.stayInfo?.cityName = $0 }
                    ))
                    .font(.subheadline)
                    .glassTextFieldStyle()
                    
                    HStack {
                        Button(role: .destructive) {
                            deleteStep(step)
                        } label: {
                            Label("Delete Step", systemImage: "trash")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .padding(.top, 4)
                }
            } else {
                Text(step.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let firstDay = stay.days.first, let lastDay = stay.days.last {
                    Text("\(formatDateStringShort(firstDay.date)) - \(formatDateStringShort(lastDay.date))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let hotel = stay.hotel {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.purple)
                            .font(.headline)
                        
                        Text("Hotel Accommodation")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                        TextField("Hotel Title", text: Binding(
                            get: { binding.wrappedValue.stayInfo?.hotel?.title ?? "" },
                            set: { binding.wrappedValue.stayInfo?.hotel?.title = $0 }
                        ))
                        .font(.headline)
                        .glassTextFieldStyle()
                        
                        TextField("Hotel Details", text: Binding(
                            get: { binding.wrappedValue.stayInfo?.hotel?.details ?? "" },
                            set: { binding.wrappedValue.stayInfo?.hotel?.details = $0 }
                        ))
                        .font(.subheadline)
                        .glassTextFieldStyle()
                    } else {
                        Text(hotel.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(hotel.details)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if let place = hotel.mapPlace {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(place.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if let phone = place.phoneNumber {
                                Text("📞 \(phone)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 8) {
                                Button {
                                    openInMaps(coordinate: place.coordinate, name: place.name)
                                } label: {
                                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }
                                
                                if let webString = place.websiteURL, let webURL = URL(string: webString) {
                                    Link(destination: webURL) {
                                        Label("Website", systemImage: "safari.fill")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .liquidGlassStyle(cornerRadius: 6, fillOpacity: 0.05, borderOpacity: 0.3)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                    }
                    
                    if isTimelineEditMode {
                        Text("Attached Files & Booking Receipts:")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        HStack(spacing: 12) {
                            Button {
                                filePickerType = .ticket
                                fileUploadTargetStepId = step.id
                                showingFilePicker = true
                            } label: {
                                Label("Attach Receipt PDF", systemImage: "doc.badge.plus")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.purple)
                                    .cornerRadius(6)
                            }
                            
                            Button {
                                filePickerType = .pass
                                fileUploadTargetStepId = step.id
                                showingFilePicker = true
                            } label: {
                                Label("Attach Pass", systemImage: "qrcode")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                            }
                        }
                        
                        if let binding = stepBinding(forId: step.id) {
                            let hotelFiles = binding.wrappedValue.stayInfo?.hotel?.sharedFiles ?? []
                            let hotelPasses = binding.wrappedValue.stayInfo?.hotel?.walletPasses ?? []
                            
                            if !hotelFiles.isEmpty || !hotelPasses.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(hotelFiles, id: \.self) { file in
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .font(.caption2)
                                            Text(file.components(separatedBy: "/").last ?? file)
                                                .font(.system(size: 10))
                                                .lineLimit(1)
                                            Spacer()
                                            Button {
                                                if var stay = binding.wrappedValue.stayInfo, var hotel = stay.hotel {
                                                    var arr = hotel.sharedFiles
                                                    if let idx = arr.firstIndex(of: file) {
                                                        arr.remove(at: idx)
                                                    }
                                                    hotel.sharedFiles = arr
                                                    stay.hotel = hotel
                                                    binding.wrappedValue.stayInfo = stay
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red)
                                                    .font(.caption2)
                                            }
                                        }
                                        .padding(6)
                                        .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.02, borderOpacity: 0.2)
                                    }
                                    
                                    ForEach(hotelPasses, id: \.self) { pass in
                                        HStack {
                                            Image(systemName: "qrcode")
                                                .font(.caption2)
                                            Text(pass.components(separatedBy: "/").last ?? pass)
                                                .font(.system(size: 10))
                                                .lineLimit(1)
                                            Spacer()
                                            Button {
                                                if var stay = binding.wrappedValue.stayInfo, var hotel = stay.hotel {
                                                    var arr = hotel.walletPasses ?? []
                                                    if let idx = arr.firstIndex(of: pass) {
                                                        arr.remove(at: idx)
                                                    }
                                                    hotel.walletPasses = arr
                                                    stay.hotel = hotel
                                                    binding.wrappedValue.stayInfo = stay
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red)
                                                    .font(.caption2)
                                            }
                                        }
                                        .padding(6)
                                        .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.02, borderOpacity: 0.2)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !isTimelineEditMode {
                        ForEach(hotelFiles, id: \.self) { file in
                            if store.downloadedFiles.contains(file) {
                                Button {
                                    if let url = store.getLocalFileURL(forFilename: file) {
                                        fileViewTitle = "Hotel Booking"
                                        selectedFileToView = IdentifiableURL(url: url)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.purple)
                                        Text("View Hotel Booking Receipt")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.05, borderOpacity: 0.3)
                                }
                            }
                        }
                        
                        let hotelPasses = hotel.getWalletPasses(forUser: user)
                        ForEach(hotelPasses, id: \.self) { passFile in
                            if store.downloadedFiles.contains(passFile) {
                                Button {
                                    if let url = store.getLocalFileURL(forFilename: passFile) {
                                        fileViewTitle = "Apple Wallet Pass"
                                        selectedFileToView = IdentifiableURL(url: url)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "qrcode.viewfinder")
                                            .foregroundColor(.purple)
                                        Text("Add to Apple Wallet")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "plus")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.05, borderOpacity: 0.3)
                                }
                            } else {
                                Button {
                                    Task {
                                        if let tripURL = URL(string: store.serverURLString) {
                                            let remoteURL = tripURL.deletingLastPathComponent().appendingPathComponent(passFile)
                                            try? await store.downloadFile(from: remoteURL, originalFilename: passFile)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundColor(.purple)
                                        Text("Download Boarding Pass")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.purple)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.05, borderOpacity: 0.3)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .liquidGlassStyle(cornerRadius: 24, fillOpacity: 0.03, borderOpacity: 0.45)
    }
    
    func stayDaysSection(_ step: Step, stay: StayStepInfo) -> some View {
        return VStack(alignment: .leading, spacing: 16) {
            if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                Button {
                    let newDayNumber = (binding.wrappedValue.stayInfo?.days.count ?? 0) + 1
                    let newDay = DayInfo(
                        dayNumber: newDayNumber,
                        date: "2026-08-18",
                        title: "New Day",
                        description: "Day description",
                        items: []
                    )
                    withAnimation {
                        binding.wrappedValue.stayInfo?.days.append(newDay)
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Day to Stay")
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            
            ForEach(stay.days) { day in
                VStack(alignment: .leading, spacing: 0) {
                    let isDayEditing = editingDayIds.contains(day.id)
                    if isDayEditing, let dayBind = dayBinding(stepId: step.id, dayId: day.id) {
                        // Edit Mode Day Header Card (Title, Description, Date)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("DAY \(day.dayNumber)")
                                    .font(.caption2)
                                    .fontWeight(.black)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Button {
                                    withAnimation {
                                        _ = editingDayIds.remove(day.id)
                                    }
                                } label: {
                                    Text("Done")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.green)
                                        .cornerRadius(6)
                                }
                            }
                            
                            TextField("Day Title", text: dayBind.title)
                                .font(.headline)
                                .glassTextFieldStyle()
                            
                            TextField("Day Description", text: dayBind.description)
                                .font(.subheadline)
                                .glassTextFieldStyle()
                            
                            TextField("Date (YYYY-MM-DD)", text: dayBind.date)
                                .font(.caption)
                                .glassTextFieldStyle()
                        }
                        .padding()
                        .background(Color(white: 1.0, opacity: 0.04))
                    } else {
                        // Read/Stay-Editing Mode Day Header Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DAY \(day.dayNumber)")
                                    .font(.caption2)
                                    .fontWeight(.black)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                
                                Text(day.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            if isTimelineEditMode {
                                // In stay-edit mode: show trash/delete button next to day
                                Button(role: .destructive) {
                                    if let idx = stepBinding(forId: step.id)?.wrappedValue.stayInfo?.days.firstIndex(where: { $0.id == day.id }) {
                                        withAnimation {
                                            _ = stepBinding(forId: step.id)?.wrappedValue.stayInfo?.days.remove(at: idx)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .padding(.trailing, 8)
                            }
                            
                            Button {
                                withAnimation {
                                    store.selectedStep = step
                                    store.selectedDayId = day.id
                                    store.selectedTab = 1
                                }
                            } label: {
                                Image(systemName: "map.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.trailing, 4)
                            
                            Text(formatDateStringShort(day.date))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 6)
                            
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(expandedDays.contains(day.id) ? 90 : 0))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.02))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if expandedDays.contains(day.id) {
                                    expandedDays.remove(day.id)
                                } else {
                                    expandedDays.insert(day.id)
                                }
                            }
                        }
                    }
                    
                    if expandedDays.contains(day.id) || isDayEditing {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            if !isDayEditing {
                                HStack {
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            _ = editingDayIds.insert(day.id)
                                        }
                                    } label: {
                                        Label("Edit Day Content", systemImage: "pencil")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(Color.orange)
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            
                            if !isDayEditing && !day.description.isEmpty {
                                Text(day.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            if !isDayEditing && day.items.isEmpty {
                                Text("No activities planned. Free day!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .padding(.horizontal)
                                    .padding(.bottom, 12)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(day.items) { item in
                                        if isDayEditing, let itemBind = itemBinding(stepId: step.id, dayId: day.id, itemId: item.id) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    Image(systemName: item.type == .hotel ? "bed.double.fill" : "mappin.and.ellipse")
                                                        .foregroundColor(.accentColor)
                                                    
                                                    TextField("Time", text: itemBind.time)
                                                        .font(.caption)
                                                        .frame(width: 80)
                                                        .glassTextFieldStyle()
                                                    
                                                    Spacer()
                                                    
                                                    Button(role: .destructive) {
                                                        if let idx = dayBinding(stepId: step.id, dayId: day.id)?.wrappedValue.items.firstIndex(where: { $0.id == item.id }) {
                                                            withAnimation {
                                                                _ = dayBinding(stepId: step.id, dayId: day.id)?.wrappedValue.items.remove(at: idx)
                                                            }
                                                        }
                                                    } label: {
                                                        Image(systemName: "minus.circle.fill")
                                                            .foregroundColor(.red)
                                                    }
                                                }
                                                
                                                TextField("Activity Title", text: itemBind.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .glassTextFieldStyle()
                                                
                                                TextField("Details", text: itemBind.details)
                                                    .font(.caption)
                                                    .glassTextFieldStyle()
                                                
                                                // Activity file manager
                                                Text("Attached Files:")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 4)
                                                
                                                HStack(spacing: 8) {
                                                    Button {
                                                        filePickerType = .ticket
                                                        fileUploadTargetStepId = "\(step.id)|\(day.id)|\(item.id)"
                                                        showingFilePicker = true
                                                    } label: {
                                                        Label("Attach PDF", systemImage: "doc.badge.plus")
                                                            .font(.system(size: 10))
                                                            .padding(6)
                                                            .background(Color.blue)
                                                            .foregroundColor(.white)
                                                            .cornerRadius(6)
                                                    }
                                                    
                                                    Button {
                                                        filePickerType = .pass
                                                        fileUploadTargetStepId = "\(step.id)|\(day.id)|\(item.id)"
                                                        showingFilePicker = true
                                                    } label: {
                                                        Label("Attach Pass", systemImage: "qrcode")
                                                            .font(.system(size: 10))
                                                            .padding(6)
                                                            .background(Color.purple)
                                                            .foregroundColor(.white)
                                                            .cornerRadius(6)
                                                    }
                                                }
                                                
                                                let itemFiles = itemBind.wrappedValue.sharedFiles
                                                if !itemFiles.isEmpty {
                                                    ForEach(itemFiles, id: \.self) { file in
                                                        HStack {
                                                            Image(systemName: "doc.text")
                                                                .font(.caption2)
                                                            Text(file.components(separatedBy: "/").last ?? file)
                                                                .font(.system(size: 10))
                                                                .lineLimit(1)
                                                            Spacer()
                                                            Button {
                                                                var arr = itemBind.wrappedValue.sharedFiles
                                                                if let idx = arr.firstIndex(of: file) {
                                                                    arr.remove(at: idx)
                                                                }
                                                                itemBind.wrappedValue.sharedFiles = arr
                                                            } label: {
                                                                Image(systemName: "minus.circle.fill")
                                                                    .foregroundColor(.red)
                                                                    .font(.caption2)
                                                            }
                                                        }
                                                        .padding(4)
                                                        .liquidGlassStyle(cornerRadius: 6, fillOpacity: 0.02, borderOpacity: 0.2)
                                                    }
                                                }
                                                let itemPasses = itemBind.wrappedValue.walletPasses ?? []
                                                if !itemPasses.isEmpty {
                                                    ForEach(itemPasses, id: \.self) { pass in
                                                        HStack {
                                                            Image(systemName: "qrcode")
                                                                .font(.caption2)
                                                            Text(pass.components(separatedBy: "/").last ?? pass)
                                                                .font(.system(size: 10))
                                                                .lineLimit(1)
                                                            Spacer()
                                                            Button {
                                                                var arr = itemBind.wrappedValue.walletPasses ?? []
                                                                if let idx = arr.firstIndex(of: pass) {
                                                                    arr.remove(at: idx)
                                                                }
                                                                itemBind.wrappedValue.walletPasses = arr
                                                            } label: {
                                                                Image(systemName: "minus.circle.fill")
                                                                    .foregroundColor(.red)
                                                                    .font(.caption2)
                                                            }
                                                        }
                                                        .padding(4)
                                                        .liquidGlassStyle(cornerRadius: 6, fillOpacity: 0.02, borderOpacity: 0.2)
                                                    }
                                                }
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.02))
                                            .cornerRadius(10)
                                        } else {
                                            activityItemCard(item, date: day.date)
                                        }
                                    }
                                    
                                    if isDayEditing, let dayBind = dayBinding(stepId: step.id, dayId: day.id) {
                                        Button {
                                            let newItem = TripItem(
                                                id: UUID().uuidString.lowercased(),
                                                type: .activity,
                                                title: "New Activity",
                                                time: "12:00 PM",
                                                details: "Details",
                                                sharedFiles: [],
                                                profileFiles: nil,
                                                walletPasses: nil,
                                                profileWalletPasses: nil,
                                                websiteURL: nil,
                                                flightNumber: nil,
                                                mapPlace: nil
                                            )
                                            withAnimation {
                                                dayBind.wrappedValue.items.append(newItem)
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Add Activity")
                                            }
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(Color.green)
                                            .cornerRadius(6)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 16)
                                .padding(.top, 8)
                            }
                            
                            if isDayEditing {
                                HStack {
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            _ = editingDayIds.remove(day.id)
                                        }
                                    } label: {
                                        Label("Done Editing", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(Color.green)
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                            }
                        }
                    }
                }
                .liquidGlassStyle(cornerRadius: 18, fillOpacity: 0.03, borderOpacity: 0.45)
            }
        }
    }
    
    func activityItemCard(_ item: TripItem, date: String) -> some View {
        let user = store.selectedUser ?? ""
        let files = item.getFiles(forUser: user)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.type == .hotel ? "bed.double.fill" : "mappin.and.ellipse")
                    .foregroundColor(.accentColor)
                    .font(.footnote)
                
                Text(item.time)
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundColor(.secondary)
                
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if !item.details.isEmpty {
                Text(item.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !files.isEmpty {
                Divider()
                    .padding(.leading, 24)
                
                ForEach(files, id: \.self) { file in
                    if store.downloadedFiles.contains(file) {
                        Button {
                            if let url = store.getLocalFileURL(forFilename: file) {
                                fileViewTitle = item.type == .flight ? "Boarding Pass" : (item.type == .train ? "Train Ticket" : "Activity Ticket")
                                selectedFileToView = IdentifiableURL(url: url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.accentColor)
                                Text("View Attached File")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }
            
            let passes = item.getWalletPasses(forUser: user)
            if !passes.isEmpty {
                Divider()
                    .padding(.leading, 24)
                
                ForEach(passes, id: \.self) { passFile in
                    if store.downloadedFiles.contains(passFile) {
                        Button {
                            if let url = store.getLocalFileURL(forFilename: passFile) {
                                fileViewTitle = "Apple Wallet Pass"
                                selectedFileToView = IdentifiableURL(url: url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "qrcode.viewfinder")
                                    .foregroundColor(.accentColor)
                                Text("Add to Apple Wallet")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 24)
                        }
                    } else {
                        Button {
                            Task {
                                if let tripURL = URL(string: store.serverURLString) {
                                    let remoteURL = tripURL.deletingLastPathComponent().appendingPathComponent(passFile)
                                    try? await store.downloadFile(from: remoteURL, originalFilename: passFile)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.accentColor)
                                Text("Download Boarding Pass")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                                Spacer()
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassStyle(cornerRadius: 14, fillOpacity: 0.015, borderOpacity: 0.3)
    }
}
