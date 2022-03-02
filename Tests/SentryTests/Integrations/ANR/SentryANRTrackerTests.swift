import XCTest

class SentryANRTrackerTests: XCTestCase, SentryANRTrackerDelegate {
    
    private var sut: SentryANRTracker!
    private var fixture: Fixture!
    private var expectation: XCTestExpectation!
    
    private class Fixture {
        let timeoutInterval : TimeInterval = 5
        let currentDate = TestCurrentDateProvider()
        let crashWrapper: TestSentryCrashAdapter
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let threadWrapper = SentryTestThreadWrapper()
        
        init() {
            crashWrapper = TestSentryCrashAdapter.sharedInstance()
        }
    }
    
    override func setUp() {
        super.setUp()
        
        expectation = expectation(description: "ANR Detection")
        fixture = Fixture()
        
        sut = SentryANRTracker(delegate: self,
                               timeoutIntervalMillis: UInt(fixture.timeoutInterval) * 1000,
                               currentDateProvider: fixture.currentDate,
                               crashAdapter: fixture.crashWrapper,
                               dispatchQueueWrapper: fixture.dispatchQueue,
                               threadWrapper: fixture.threadWrapper)
    }
    
    override func tearDown() {
        super.tearDown()
        sut.stop()
    }
    
    func testContinousANR_OneReported() {
        fixture.dispatchQueue.blockBeforeMainBlock =  {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            return false
        }
        sut.start()
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testANRButAppInBackground_NoANR() {
        expectation.isInverted = true
        fixture.crashWrapper.internalIsApplicationInForeground = false
        
        fixture.dispatchQueue.blockBeforeMainBlock =  {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            return false
        }
        sut.start()
        
        wait(for: [expectation], timeout: 0.01)
    }
    
    func testMultipleANRs_MultipleReported() {
        expectation.expectedFulfillmentCount = 3
        
        fixture.dispatchQueue.blockBeforeMainBlock =  {
            self.advanceTime(bySeconds: self.fixture.timeoutInterval)
            let invocations = self.fixture.dispatchQueue.blockOnMainInvocations.count
            if ([0,2,3,5].contains(invocations)) {
                return true
            }
            
            return false
        }
        sut.start()
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testAppSuspended_NoANR() {
        expectation.isInverted = true
        fixture.dispatchQueue.blockBeforeMainBlock =  {
            let delta = self.fixture.timeoutInterval * 2
            self.advanceTime(bySeconds: delta)
            return false
        }
        sut.start()
        
        wait(for: [expectation], timeout: 0.01)
    }
    
    func testStop_StopsReportingANRs() {
        expectation.isInverted = true
        
        let mainBlockExpectation = expectation(description: "Main Block")
        fixture.dispatchQueue.blockBeforeMainBlock =  {
            self.sut.stop()
            mainBlockExpectation.fulfill()
            return true
        }
        
        sut.start()
        
        wait(for: [expectation, mainBlockExpectation], timeout: 0.01)
    }
    
    func anrDetected() {
        expectation.fulfill()
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDate.setDate(date: fixture.currentDate.date().addingTimeInterval(bySeconds))
    }
}
