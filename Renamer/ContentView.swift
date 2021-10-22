//
//  ContentView.swift
//  Renamer
//
//  Created by Alexey Bodnya on 21.10.2021.
//

import SwiftUI
import PythonKit

struct ContentView: View {
    
    @State var directoryPath: String?
    @State var fileNames: [String] = []
    @State var newFileNames: [String: String] = [:]
    @State var isAnalysingFiles = false
    @State var isRenamingFiles = false
    @State var isRenamingProcessed = 0
    
    var body: some View {
        VStack(spacing: 0) {
            makeFileSelector()
            ZStack(alignment: Alignment(horizontal: .center, vertical: .center)) {
                Color.white.frame(width: 600, height: 480, alignment: .center)
                if directoryPath != nil {
                    if isAnalysingFiles {
                        Text("Analysing…")
                    } else {
                        VStack(spacing: 0) {
                            makeList()
                            Divider()
                            if isRenamingFiles {
                                Text("Renaming… \(isRenamingProcessed) / \(newFileNames.count)").padding()
                            } else {
                                Button("Rename", action: renameFiles).padding()
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder func makeFileSelector() -> some View {
        HStack {
            Text(directoryPath ?? "<No directory selected>")
            Button("Select File") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = true
                if panel.runModal() == .OK {
                    self.directoryPath = panel.url?.path
                    if let directoryPath = directoryPath, let fileNames = try? FileManager.default.contentsOfDirectory(atPath: directoryPath) {
                        self.fileNames = fileNames.sorted()
                        analyzeFiles()
                    }
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder func makeList() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("From").font(.title3)
                Spacer()
                Text("To").font(.title3)
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal)
            
            List {
                ForEach(fileNames, id: \.self) { fileName in
                    let index = fileNames.firstIndex(of: fileName)!
                    HStack {
                        Text(fileName)
                        Spacer()
                        Text(newFileNames[fileName] ?? fileName)
                            .foregroundColor(newFileNames[fileName] == nil ? .red : .primary)
                        Spacer()
                    }
                    .listRowBackground(index % 2 == 1 ? Color.blue.opacity(0.1) : .clear)
                }
            }
        }
    }
    
    func analyzeFiles() {
        guard let directoryPath = directoryPath else {
            return
        }
        isAnalysingFiles = true
        DispatchQueue.global().async {
            copyScripts()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            for fileName in fileNames {
                let url = URL(fileURLWithPath: directoryPath).appendingPathComponent(fileName)
                if let date = creationDate(fileURL: url) {
                    let formatted = formatter.string(from: date)
                    if !fileName.hasPrefix(formatted) {
                        let newFileName = formatted + "-" + fileName
                        newFileNames[fileName] = newFileName
                    } else {
                        newFileNames[fileName] = fileName
                    }
                }
            }
            isAnalysingFiles = false
        }
    }
    
    func renameFiles() {
        guard let directoryPath = directoryPath else {
            return
        }
        isRenamingFiles = true
        DispatchQueue.global().async {
            for fileName in fileNames {
                let url = URL(fileURLWithPath: directoryPath).appendingPathComponent(fileName)
                if let newName = newFileNames[fileName] {
                    if newName != fileName {
                        let newUrl = URL(fileURLWithPath: directoryPath).appendingPathComponent(newName)
                        try? FileManager.default.moveItem(at: url, to: newUrl)
                    }
                    isRenamingProcessed += 1
                }
            }
            isRenamingFiles = false
        }
    }
    
    func copyScripts() {
        try? FileManager.default.copyItem(
            at: Bundle.main.url(forResource: "ccl_bplist", withExtension: "py", subdirectory: nil)!,
            to: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("ccl_bplist.py")
        )
        try? FileManager.default.copyItem(
            at: Bundle.main.url(forResource: "parse", withExtension: "py", subdirectory: nil)!,
            to: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("parse.py")
        )
    }
    
    func creationDate(fileURL: URL) -> Date? {
        if let data = try? Xattr.dataFor(named: "com.apple.assetsd.customCreationDate", atPath: fileURL.path), let result = parseDate(data: data) {
            return result
        } else if let data = try? Xattr.dataFor(named: "com.apple.assetsd.addedDate", atPath: fileURL.path), let result = parseDate(data: data) {
            return result
        } else if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path), let date = attributes[.creationDate] as? Date {
            let components = Calendar.current.dateComponents([.day, .month, .year], from: date)
            let today = Calendar.current.dateComponents([.day, .month, .year], from: Date())
            if components.day == today.day && components.month == today.month && components.year == today.year {
                // not today
                return nil
            } else {
                return date
            }
        }
        return nil
    }
    
    func parseDate(data: Data) -> Date? {
        // Write temp file with binary plist
        let dateUrl = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("date")
        if FileManager.default.fileExists(atPath: dateUrl.path) {
            try? FileManager.default.removeItem(at: dateUrl)
        }
        try? data.write(to: dateUrl)
        
        // parse it with python
        let sys = Python.import("sys")
        sys.path.append(NSHomeDirectory())
        let pythonScript = Python.import("parse")
        let parsed = pythonScript.parse()
        
        // convert to Date
        guard let timestamp = Double(parsed.description) else {
            return nil
        }
        let date = Date(timeIntervalSince1970: timestamp)
        return date
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
