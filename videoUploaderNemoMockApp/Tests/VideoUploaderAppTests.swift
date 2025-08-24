import XCTest
 @testable import VideoUploaderNemoMockApp

final class ContentViewModelTests: XCTestCase {
    var viewModel: ContentViewModel!
    var mockNetworkService: MockNetworkService!
    var mockFileService: MockFileService!
    var mockVideoProcessingService: MockVideoProcessingService!
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        mockFileService = MockFileService()
        mockVideoProcessingService = MockVideoProcessingService()
        
        viewModel = ContentViewModel(
            networkService: mockNetworkService,
            fileService: mockFileService,
            videoProcessingService: mockVideoProcessingService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockNetworkService = nil
        mockFileService = nil
        mockVideoProcessingService = nil
        super.tearDown()
    }
    
    @MainActor
    func testFetchHelloWorld_Success() async {
        // Given
        mockNetworkService.helloWorldResult = .success("Hello, World!")
        
        // When
        viewModel.fetchHelloWorld()
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(viewModel.helloWorldMessage, "Hello, World!")
    }
    
    @MainActor
    func testFetchHelloWorld_Failure() async {
        // Given
        mockNetworkService.helloWorldResult = .failure(NetworkError.invalidResponse)
        
        // When
        viewModel.fetchHelloWorld()
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertTrue(viewModel.helloWorldMessage.contains("Error:"))
    }
    
    @MainActor
    func testUploadVideo_NoVideoSelected() {
        // Given
        viewModel.videoURL = nil
        
        // When
        viewModel.uploadVideo()
        
        // Then
        XCTAssertEqual(viewModel.uploadStatus, "Please select a video first.")
    }
    
    @MainActor
    func testSelectVideo_Success() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/video.mov")
        let processedURL = URL(fileURLWithPath: "/test/processed_video.mp4")
        mockVideoProcessingService.processResult = .success(processedURL)
        
        // When
        viewModel.selectVideo(url: testURL)
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(viewModel.videoURL, processedURL)
    }
}

// MARK: - Mock Services

class MockNetworkService: NetworkServiceProtocol {
    var helloWorldResult: Result<String, Error> = .success("Mock Hello World")
    var uploadResult: Result<FileResponse, Error> = .success(FileResponse(
        download_url: "https://example.com/download",
        message: "Success",
        processing_time: "1.5s"
    ))
    var downloadResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/test.zip"))
    
    func fetchHelloWorld() async throws -> String {
        switch helloWorldResult {
        case .success(let message):
            return message
        case .failure(let error):
            throw error
        }
    }
    
    func uploadVideo(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> FileResponse {
        progressHandler(1.0)
        switch uploadResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
    
    func downloadFile(from urlString: String, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        progressHandler(1.0)
        switch downloadResult {
        case .success(let url):
            return url
        case .failure(let error):
            throw error
        }
    }
}

class MockFileService: FileServiceProtocol {
    var extractResult: Bool = true
    var organizeResult: [FolderItem] = []
    var downloadedFolders: [URL] = []
    
    func extractZipFile(from zipURL: URL, to extractPath: URL) async throws -> Bool {
        return extractResult
    }
    
    func organizeImagesIntoFolders(at path: URL) async throws -> [FolderItem] {
        return organizeResult
    }
    
    func saveDownloadedFolder(at path: URL) {
        downloadedFolders.append(path)
    }
    
    func getDownloadedFolders() -> [URL] {
        return downloadedFolders
    }
    
    func createUniqueExtractionPath() -> URL {
        return URL(fileURLWithPath: "/tmp/extract_\(UUID().uuidString)")
    }
    
    func cleanupOldExtractions() {
        // Mock implementation
    }
}

class MockVideoProcessingService: VideoProcessingServiceProtocol {
    var processResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/processed.mp4"))
    
    func processVideo(from url: URL) async throws -> URL {
        switch processResult {
        case .success(let processedURL):
            return processedURL
        case .failure(let error):
            throw error
        }
    }
}
