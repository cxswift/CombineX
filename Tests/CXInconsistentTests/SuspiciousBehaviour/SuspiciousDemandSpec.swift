import Foundation
import Quick
import Nimble
import CXShim

class SuspiciousDemandSpec: QuickSpec {
    
    typealias Demand = Subscribers.Demand
    
    override func spec() {
        
        // MARK: - Calculate
        describe("Calculate") {
            
            // MARK: Doc says "any operation that would result in a negative value is clamped to .max(0)", but it will actually crash in Combine.
            it("result should clamped to .max(0) as documented") {
                #if !SWIFT_PACKAGE
                
                expect {
                    Demand.max(1) - .max(2)
                }.toBranch(combine: throwAssertion(), cx: equal(.max(0)))
                
                #endif
            }
        }
    }
}