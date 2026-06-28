import SwiftUI
import MapKit

extension TimelineView {
    func flightSummaryCard(_ step: Step) -> some View {
        guard let flight = step.flightInfo else { return AnyView(EmptyView()) }
        let type = step.type
        
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(type == .flight ? "FLIGHT" : (type == .train ? "TRAIN" : "ROAD TRIP"))
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(type == .flight ? Color.blue : (type == .train ? Color.orange : Color.green))
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
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 4)
                    }
                    
                    Text(formatDateString(flight.date))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                
                if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Step Title", text: binding.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .glassTextFieldStyle()
                        
                        HStack {
                            TextField("Operator (Airline/Car)", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.airline ?? "" },
                                set: { binding.wrappedValue.flightInfo?.airline = $0 }
                            ))
                            .glassTextFieldStyle()
                            
                            TextField("Number/ID", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.flightNumber ?? "" },
                                set: { binding.wrappedValue.flightInfo?.flightNumber = $0 }
                            ))
                            .glassTextFieldStyle()
                        }
                        
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
                    }
                } else {
                    Text(step.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                HStack(alignment: .center) {
                    if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("From", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.departureAirport.name ?? "" },
                                set: { newName in
                                    if var info = binding.wrappedValue.flightInfo {
                                        info.departureAirport = LocationInfo(
                                            name: newName,
                                            latitude: info.departureAirport.latitude,
                                            longitude: info.departureAirport.longitude
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .font(.caption)
                            .glassTextFieldStyle()
                            
                            TextField("Time", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.departureTime ?? "" },
                                set: { binding.wrappedValue.flightInfo?.departureTime = $0 }
                            ))
                            .font(.caption)
                            .glassTextFieldStyle()
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Image(systemName: type == .flight ? "airplane" : (type == .train ? "train.side.front.car" : "car.fill"))
                                .font(.headline)
                                .foregroundColor(.accentColor)
                            
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.4))
                                .frame(height: 1)
                                .frame(width: 50)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 6) {
                            TextField("To", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.arrivalAirport.name ?? "" },
                                set: { newName in
                                    if var info = binding.wrappedValue.flightInfo {
                                        info.arrivalAirport = LocationInfo(
                                            name: newName,
                                            latitude: info.arrivalAirport.latitude,
                                            longitude: info.arrivalAirport.longitude
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .font(.caption)
                            .glassTextFieldStyle()
                            
                            TextField("Time", text: Binding(
                                get: { binding.wrappedValue.flightInfo?.arrivalTime ?? "" },
                                set: { binding.wrappedValue.flightInfo?.arrivalTime = $0 }
                            ))
                            .font(.caption)
                            .glassTextFieldStyle()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(flight.departureAirport.name.components(separatedBy: " (").first ?? "DEP")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(flight.departureTime)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Image(systemName: type == .flight ? "airplane" : (type == .train ? "train.side.front.car" : "car.fill"))
                                .font(.headline)
                                .foregroundColor(.accentColor)
                            
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.4))
                                .frame(height: 1)
                                .frame(width: 80)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(flight.arrivalAirport.name.components(separatedBy: " (").first ?? "ARR")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(flight.arrivalTime)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                    TextField("Details", text: Binding(
                        get: { binding.wrappedValue.flightInfo?.details ?? "" },
                        set: { binding.wrappedValue.flightInfo?.details = $0 }
                    ))
                    .font(.subheadline)
                    .glassTextFieldStyle()
                } else {
                    Text(flight.details)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .liquidGlassStyle(cornerRadius: 24, fillOpacity: 0.03, borderOpacity: 0.45)
        )
    }
    
    func flightDetailsSection(_ step: Step) -> some View {
        guard let flight = step.flightInfo else { return AnyView(EmptyView()) }
        let type = step.type
        let user = store.selectedUser ?? ""
        var flightFiles: [String] = []
        if let shared = flight.sharedFiles { flightFiles.append(contentsOf: shared) }
        if let profile = flight.profileFiles?[user] { flightFiles.append(profile) }
        
        var flightPasses: [String] = []
        if let walletShared = flight.walletPasses { flightPasses.append(contentsOf: walletShared) }
        if let walletProfile = flight.profileWalletPasses?[user] { flightPasses.append(walletProfile) }
        let validFlightPasses = flightPasses.filter { store.downloadedFiles.contains($0) && isValidPKPass(file: $0, store: store) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                if isTimelineEditMode, let binding = stepBinding(forId: step.id) {
                    Text("Itinerary Map Settings")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Departure Coordinates:")
                            .font(.caption)
                            .fontWeight(.bold)
                        HStack {
                            TextField("Lat", text: Binding(
                                get: { String(format: "%.4f", binding.wrappedValue.flightInfo?.departureAirport.latitude ?? 0.0) },
                                set: { newLatStr in
                                    if var info = binding.wrappedValue.flightInfo {
                                        let newLat = Double(newLatStr) ?? info.departureAirport.latitude
                                        info.departureAirport = LocationInfo(
                                            name: info.departureAirport.name,
                                            latitude: newLat,
                                            longitude: info.departureAirport.longitude
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .glassTextFieldStyle()
                            
                            TextField("Lng", text: Binding(
                                get: { String(format: "%.4f", binding.wrappedValue.flightInfo?.departureAirport.longitude ?? 0.0) },
                                set: { newLngStr in
                                    if var info = binding.wrappedValue.flightInfo {
                                        let newLng = Double(newLngStr) ?? info.departureAirport.longitude
                                        info.departureAirport = LocationInfo(
                                            name: info.departureAirport.name,
                                            latitude: info.departureAirport.latitude,
                                            longitude: newLng
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .glassTextFieldStyle()
                        }
                        
                        Text("Arrival Coordinates:")
                            .font(.caption)
                            .fontWeight(.bold)
                        HStack {
                            TextField("Lat", text: Binding(
                                get: { String(format: "%.4f", binding.wrappedValue.flightInfo?.arrivalAirport.latitude ?? 0.0) },
                                set: { newLatStr in
                                    if var info = binding.wrappedValue.flightInfo {
                                        let newLat = Double(newLatStr) ?? info.arrivalAirport.latitude
                                        info.arrivalAirport = LocationInfo(
                                            name: info.arrivalAirport.name,
                                            latitude: newLat,
                                            longitude: info.arrivalAirport.longitude
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .glassTextFieldStyle()
                            
                            TextField("Lng", text: Binding(
                                get: { String(format: "%.4f", binding.wrappedValue.flightInfo?.arrivalAirport.longitude ?? 0.0) },
                                set: { newLngStr in
                                    if var info = binding.wrappedValue.flightInfo {
                                        let newLng = Double(newLngStr) ?? info.arrivalAirport.longitude
                                        info.arrivalAirport = LocationInfo(
                                            name: info.arrivalAirport.name,
                                            latitude: info.arrivalAirport.latitude,
                                            longitude: newLng
                                        )
                                        binding.wrappedValue.flightInfo = info
                                    }
                                }
                            ))
                            .glassTextFieldStyle()
                        }
                    }
                    .padding()
                    .liquidGlassStyle(cornerRadius: 16, fillOpacity: 0.015, borderOpacity: 0.25)
                }
                
                if type == .flight && !isTimelineEditMode {
                    Text("Live Flight Tracker")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                    
                    FlightStatusTrackerView(flightNumber: flight.flightNumber, date: flight.date, store: store)
                }
                
                if type == .car {
                    Text("Road Trip Route")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text("Start Point")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(flight.departureAirport.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.down")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .padding(.leading, 6)
                            Text("Florida's Turnpike South (Approx. 4 hours)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text("End Point")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(flight.arrivalAirport.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlassStyle(cornerRadius: 16, fillOpacity: 0.015, borderOpacity: 0.25)
                }
                
                if isTimelineEditMode && type != .car {
                    Text("File Attachments Manager")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                        .padding(.top, 10)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                filePickerType = .ticket
                                fileUploadTargetStepId = step.id
                                showingFilePicker = true
                            } label: {
                                Label("Upload PDF", systemImage: "doc.badge.plus")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            
                            Button {
                                filePickerType = .pass
                                fileUploadTargetStepId = step.id
                                showingFilePicker = true
                            } label: {
                                Label("Upload Pass", systemImage: "qrcode")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.purple)
                                    .cornerRadius(8)
                            }
                        }
                        
                        if let binding = stepBinding(forId: step.id) {
                            let shared = binding.wrappedValue.flightInfo?.sharedFiles ?? []
                            let wallet = binding.wrappedValue.flightInfo?.walletPasses ?? []
                            
                            if !shared.isEmpty || !wallet.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(shared, id: \.self) { file in
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .foregroundColor(.secondary)
                                            Text(file.components(separatedBy: "/").last ?? file)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Spacer()
                                            Button {
                                                if var fInfo = binding.wrappedValue.flightInfo {
                                                    var arr = fInfo.sharedFiles ?? []
                                                    if let idx = arr.firstIndex(of: file) {
                                                        arr.remove(at: idx)
                                                    }
                                                    fInfo.sharedFiles = arr
                                                    binding.wrappedValue.flightInfo = fInfo
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(8)
                                        .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.02, borderOpacity: 0.25)
                                    }
                                    
                                    ForEach(wallet, id: \.self) { pass in
                                        HStack {
                                            Image(systemName: "qrcode")
                                                .foregroundColor(.secondary)
                                            Text(pass.components(separatedBy: "/").last ?? pass)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Spacer()
                                            Button {
                                                if var fInfo = binding.wrappedValue.flightInfo {
                                                    var arr = fInfo.walletPasses ?? []
                                                    if let idx = arr.firstIndex(of: pass) {
                                                        arr.remove(at: idx)
                                                    }
                                                    fInfo.walletPasses = arr
                                                    binding.wrappedValue.flightInfo = fInfo
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(8)
                                        .liquidGlassStyle(cornerRadius: 8, fillOpacity: 0.02, borderOpacity: 0.25)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .liquidGlassStyle(cornerRadius: 16, fillOpacity: 0.015, borderOpacity: 0.25)
                }
                
                if !isTimelineEditMode && type != .car && (!flightFiles.isEmpty || !validFlightPasses.isEmpty) {
                    Text("Tickets & Boarding Passes")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.leading, 4)
                        .padding(.top, 10)
                    
                    ForEach(flightFiles, id: \.self) { file in
                        if store.downloadedFiles.contains(file) {
                            HStack(spacing: 8) {
                                Button {
                                    if let url = store.getLocalFileURL(forFilename: file) {
                                        fileViewTitle = type == .flight ? "Boarding Pass" : "Train Ticket"
                                        selectedFileToView = IdentifiableURL(url: url)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: type == .flight ? "airplane" : "tram.fill")
                                            .foregroundColor(.accentColor)
                                        Text(type == .flight ? "View Boarding Pass" : "View Train Ticket")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                                }
                                
                                if let url = store.getLocalFileURL(forFilename: file) {
                                    ShareLink(item: url) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.subheadline)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                                    }
                                }
                            }
                        } else {
                            Button {
                                Task {
                                    if let tripURL = URL(string: store.serverURLString) {
                                        let remoteURL = tripURL.deletingLastPathComponent().appendingPathComponent(file)
                                        try? await store.downloadFile(from: remoteURL, originalFilename: file)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.accentColor)
                                    Text(type == .flight ? "Download Boarding Pass" : "Download Train Ticket")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentColor)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                            }
                        }
                    }
                    
                    ForEach(validFlightPasses, id: \.self) { passFile in
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
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .liquidGlassStyle(cornerRadius: 12, fillOpacity: 0.015, borderOpacity: 0.25)
                        }
                    }
                }
            }
        )
    }
}
