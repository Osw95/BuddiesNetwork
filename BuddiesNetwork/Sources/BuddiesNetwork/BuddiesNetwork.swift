// The Swift Programming Language
// https://docs.swift.org/swift-book
//
//  NetworkFile.swift
//  networkTest
//
//  Created by Oswaldo Ferral Mejia on 06/04/25.
//

import Foundation

@globalActor
actor BDNGlobalNetworkManager {
    static let shared = BDNNetworkManager()
}


@BDNGlobalNetworkManager
public final class BDNNetworkManager {
    public static let shared = EKTNetworkManager()
    private let session: URLSession
    private var arrRqModel: [URLRequest]?
    private let operationQueue = OperationQueue()
    private let configuration = URLSessionConfiguration.default
    var completedCount: Double = 0
    
    
    private init () {
        operationQueue.maxConcurrentOperationCount = 4
        configuration.timeoutIntervalForRequest = 30
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration, delegate: nil, delegateQueue: operationQueue)
        session.sessionDescription = "ElektraNetworkManager"
    }
    
    
    /// Fetch multiple url request with just 4 active tasks ensuring that the request and process would be executed in other thread.
    /// Also we insure that our context would be change just 2 times using less energy and resources than other methods
    /// Use ``BDNNetworkManager/completedCount`` to retrive how many tasks were completed
    /// - Parameter arrUrl: `[URLRequest]` that represents an array of requests
    /// - Returns: `[Result<T, Error>]` that represents an array of results
    public func loadMultipleData<T: Sendable>(_ arrUrl: [URLRequest]) async -> [Result<T, Error>] {
        guard !arrUrl.isEmpty else { return [] }
        self.arrRqModel = arrUrl
        return await withTaskGroup(of: (Result<T, Error>?).self, returning: [Result].self) { [weak self] group in
            let maxRqTask = min(4, arrUrl.count)
            guard let self else {return []}
            var iNextTaskIndex: Int = maxRqTask
            for rqTasks in 0..<maxRqTask {
                group.addTask {
                    await self.getUrlToLoad(rqTasks)
                }
            }
            var getDownloadedData = [Result<T, Error>]()
            for await getDownload in group {
                if iNextTaskIndex < arrUrl.count {
                    let copyForContext = iNextTaskIndex
                    group.addTask { await self.getUrlToLoad(copyForContext) }
                    iNextTaskIndex += 1
                }
                if getDownload != nil {
                    getDownloadedData.append(getDownload ?? .failure(NetworkError.noDecodable))
                }
            }
            return getDownloadedData
        }
    }
    
    
    
    /// Fetch a `URLRequest` with the global NetworkManager configuration
    /// - Parameter url: Request with default networking configuration
    /// - Returns: Generic Result
    public func loadData<T>(from url: URLRequest) async -> Result<T, Error> {
        do {
            let (data, _) = try await session.data(for: url)
            guard let data = data as? T else { return .failure(NetworkError.noValidData)}
            return .success(data)
        } catch {
            return .failure(error)
        }
    }
    
    private func getUrlToLoad<T>(_ index: Int) async -> Result<T, Error> {
        guard let urlRQ = arrRqModel?[index] else { return .failure(NetworkError.indexNotFound) }
        completedCount += 1
        return await loadData(from: urlRQ)
    }
}


enum NetworkError: Error {
    case indexNotFound, noValidUrl, noValidData, noDecodable
}

