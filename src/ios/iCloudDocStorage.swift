@objc(iCloudDocStorage) class iCloudDocStorage : CDVPlugin {
    var pluginResult: CDVPluginResult?
    var ubiquitousContainerID: String?
    var ubiquitousContainerURL: URL?
    
    // initUbiquitousContainer: Checks user is signed into iCloud and initialises the desired ubiquitous container.
    @objc(initUbiquitousContainer:)
    func initUbiquitousContainer(command: CDVInvokedUrlCommand) {
        self.ubiquitousContainerID = command.arguments[0] as? String
        
        // If user is not signed into iCloud, return error
        if (FileManager.default.ubiquityIdentityToken == nil) {
            return self.commandDelegate!.send(
                CDVPluginResult(
                    status: CDVCommandStatus_ERROR
                ),
                callbackId: command.callbackId
            )
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Initialise and store the ubiquitous container url
            self.ubiquitousContainerURL = self.getUbiquitousContainerURL(self.ubiquitousContainerID)
            
            if (self.ubiquitousContainerURL != nil) {
                NSLog((self.ubiquitousContainerURL?.absoluteString)!)
                
                self.pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: self.ubiquitousContainerURL?.absoluteString
                )
            }
            else {
                self.pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR
                )
            }
            
            self.commandDelegate!.send(
                self.pluginResult,
                callbackId: command.callbackId
            )
        }
    }
    
    
    // syncToCloud: Sends the file at the given local URL to the ubiquitous container for syncing to iCloud.
    @objc(syncToCloud:)
    func syncToCloud(command: CDVInvokedUrlCommand) {
        // Get the file to sync's url
        let fileURLArg = command.arguments[0] as? String
        
        if (fileURLArg != nil) {
            NSLog(fileURLArg!)
            
            // Convert fileUrl to URL
            let fileURL = URL.init(string: fileURLArg!)
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Initialise and store the ubiquitous container url if necessary
                if (self.ubiquitousContainerURL == nil) {
                    self.ubiquitousContainerURL = self.getUbiquitousContainerURL(self.ubiquitousContainerID)
                }
                
                // Get the destination URL of the file within the iCloud ubiquitous container
                let fileUrlInUbiquitousContainer = self.ubiquitousContainerURL?
                    .appendingPathComponent("Documents")
                    .appendingPathComponent((fileURL?.lastPathComponent)!)
                
                do {
                    // Tell iOS to move the file to the ubiquitous container and sync to iCloud
                    try FileManager.default.setUbiquitous(
                        true,
                        itemAt: fileURL!,
                        destinationURL: fileUrlInUbiquitousContainer!)
                    
                    self.pluginResult = CDVPluginResult(
                        status: CDVCommandStatus_OK
                    )
                }
                catch {
                    self.pluginResult = CDVPluginResult(
                        status: CDVCommandStatus_ERROR
                    )
                }
                
                self.commandDelegate!.send(
                    self.pluginResult,
                    callbackId: command.callbackId
                )
            }
        }
        else {
            self.commandDelegate!.send(
                CDVPluginResult(
                    status: CDVCommandStatus_OK
                ),
                callbackId: command.callbackId
            )
        }
    }
    
     @objc(base64:)
    func base64(command: CDVInvokedUrlCommand) {
        do {
            self.ubiquitousContainerID  = "";
            if (self.ubiquitousContainerURL == nil) {
                self.ubiquitousContainerURL = self.getUbiquitousContainerURL(self.ubiquitousContainerID)
            }
            
            let filePath = command.arguments[0] as? String;
            let fileURL = URL.init(string: filePath!)
            let fileManager = FileManager.default;
            
            if fileManager.fileExists(atPath: (fileURL!.path)) {
                let fileData = try Data.init(contentsOf: fileURL!)
                let fileStream:String = fileData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0));
                
                self.commandDelegate!.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_OK,
                        messageAs: fileStream
                    ),
                    callbackId: command.callbackId
                )
            } else {
                self.commandDelegate!.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_ERROR,
                        messageAs: fileURL?.absoluteString
                    ),
                    callbackId: command.callbackId
                )
            }
        } catch {
            self.commandDelegate!.send(
                CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error.localizedDescription
                ),
                callbackId: command.callbackId
            )
        }
    }
    
    @objc(removeiCloudFile:)
    func removeiCloudFile(command: CDVInvokedUrlCommand) {
        
        self.ubiquitousContainerID  = "";
        if (self.ubiquitousContainerURL == nil) {
            self.ubiquitousContainerURL = self.getUbiquitousContainerURL(self.ubiquitousContainerID)
        }
        
        let filePath = command.arguments[0] as? String;
        let fileURL = URL.init(string: filePath!)
        let fileManager = FileManager.default;
        
        if fileManager.fileExists(atPath: (fileURL!.path)) {
            do {
               try fileManager.removeItem(at: fileURL!);
            } catch let error as NSError {
                NSLog("Unable to remove directory \(error.debugDescription)")
            }
            self.commandDelegate!.send(
                CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: "OK"
                ),
                callbackId: command.callbackId
            )
        } else {
            self.commandDelegate!.send(
                CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: fileURL?.absoluteString
                ),
                callbackId: command.callbackId
            )
        }
    }
    
    @objc(fileList:)
    func fileList(command: CDVInvokedUrlCommand) {
        do {
            self.ubiquitousContainerID  = "";
            if (self.ubiquitousContainerURL == nil) {
                self.ubiquitousContainerURL = self.getUbiquitousContainerURL(self.ubiquitousContainerID)
            }
            
            let folder = command.arguments[0] as? String;
            let fileUrlInUbiquitousContainer = self.ubiquitousContainerURL?
                .appendingPathComponent("Documents")
                .appendingPathComponent(folder!);
            let fileManager = FileManager.default;
            
            do {
                try fileManager.createDirectory(atPath: fileUrlInUbiquitousContainer!.path, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                NSLog("Unable to create directory \(error.debugDescription)")
            }
            let files = try? FileManager.default.contentsOfDirectory(at: (fileUrlInUbiquitousContainer?.absoluteURL)!,
                                                                     includingPropertiesForKeys: [.contentModificationDateKey],
                                                                    options:.skipsHiddenFiles);
            // Sort Files
            var urls: [URL] = [];
            for file in files!
            {
                urls.append(file);
            }
            let arrayFiles = urls.map { url in
                (url.lastPathComponent, (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast)
                }
                .sorted(by: { $0.1 > $1.1 }) // sort descending modification dates
                .map { $0.0 } // extract file names
            
            // Return data in Base64
            var data: [[String: String]] = [];
            for fileName in arrayFiles
            {
                let url = fileUrlInUbiquitousContainer?.appendingPathComponent(fileName);
                let fileData = try Data.init(contentsOf: url!)
                let fileStream:String = fileData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0));
                let info:[String: String] = [(url?.absoluteString)!: fileStream];
                data.append(info);
            }
            
            self.commandDelegate!.send(
                CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: data
                ),
                callbackId: command.callbackId
            )

            
            
        } catch {
            self.commandDelegate!.send(
                CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error.localizedDescription
                ),
                callbackId: command.callbackId
            )
        }
        
        
        
    }
    
    @objc(downloadFile:)
    func downloadFile(command: CDVInvokedUrlCommand) {
        // Get the file to sync's url
        let fileURLArg = command.arguments[0] as? String
        
        if (fileURLArg != nil) {
            NSLog(fileURLArg!)
            
            // Convert fileUrl to URL
            let fileURL = URL.init(string: fileURLArg!)
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Initialise and store the ubiquitous container url if necessary
                if (self.ubiquitousContainerURL == nil) {
                    self.ubiquitousContainerURL = self.getUbiquitousContainerURL(self.ubiquitousContainerID)
                }
                
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: fileURL!)
                    
                    NSLog("Downloading file \(fileURL)")

                    self.pluginResult = CDVPluginResult(
                        status: CDVCommandStatus_OK
                    )
                }
                catch {
                    NSLog("Error Downloading file \(fileURL)")
                    self.pluginResult = CDVPluginResult(
                        status: CDVCommandStatus_ERROR
                    )
                }
                
                self.commandDelegate!.send(
                    self.pluginResult,
                    callbackId: command.callbackId
                )
            }
        }
        else {
            self.commandDelegate!.send(
                CDVPluginResult(
                    status: CDVCommandStatus_OK
                ),
                callbackId: command.callbackId
            )
        }
    }
    
    private func getUbiquitousContainerURL(_ containerId: String?) -> URL? {
        if let iCloudContainerUrl = FileManager.default.url(forUbiquityContainerIdentifier: containerId) {
            NSLog("iCloud is on")
            return iCloudContainerUrl
        }   else {
            NSLog("iCloud is off")
            return nil
        }
    }
}
