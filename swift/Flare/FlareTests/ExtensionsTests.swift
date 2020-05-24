//
//  FlareTests.swift
//  FlareTests
//
//  Created by Andrew Zamler-Carhart on 5/24/20.
//  Copyright © 2020 Andrew Zamler-Carhart. All rights reserved.
//

@testable import Flare
import XCTest

class FlareTests: XCTestCase {
    let point0 = CGPoint(x: 0, y: 0)
    let point1 = CGPoint(x: 10, y: 10)
    let point2 = CGPoint(x: 20, y: 20)
    let point3D0 = Point3D(x: CGFloat(0), y: CGFloat(0), z: CGFloat(0))
    let point3D1 = Point3D(x: CGFloat(10), y: CGFloat(10), z: CGFloat(10))
    let point3D2 = Point3D(x: CGFloat(20), y: CGFloat(20), z: CGFloat(20))
    let size1 = CGSize(width: 10, height: 10)
    let size2 = CGSize(width: 20, height: 20)
    let size3D1 = Size3D(width: 10, height: 10, depth: 10)
    let size3D2 = Size3D(width: 20, height: 20, depth: 20)

    override func setUp() {

    }

    override func tearDown() {

    }

    func testDictionaryEquality() {
        XCTAssert(["key": "value"] == ["key": "value"])
        XCTAssert(["key": "value"] != ["key": "foobar"])
    }

    func testPoint3DEquality() {
        XCTAssert(point3D1 == point3D1)
        XCTAssert(point3D1 != point3D2)
    }

    func testSize3DEquality() {
        XCTAssert(size3D1 == size3D1)
        XCTAssert(size3D1 != size3D2)
    }

    func testCube3DEquality() {
        XCTAssert(Cube3D(origin: point3D1, size: size3D1) ==
            Cube3D(origin: point3D1, size: size3D1))
        XCTAssert(Cube3D(origin: point3D1, size: size3D1) !=
            Cube3D(origin: point3D2, size: size3D2))
    }

    func testAddition() {
        XCTAssertEqual(point1 + size1, point2)
        XCTAssertEqual(point3D1 + size3D1, point3D2)
    }

    func testSubtraction() {
        XCTAssertEqual(point2 - size1, point1)
        XCTAssertEqual(point3D2 - size3D1, point3D1)
    }

    func testDistance() {
        XCTAssertEqual(point2 - point1, 14.142135623730951)
        XCTAssertEqual(point3D2 - point3D1, 17.320508075688775)
    }

    func testSizeDifference() {
        XCTAssertEqual(size2 - size1, size1)
        XCTAssertEqual(size3D2 - size3D1, size3D1)
    }

    func testScalePoint() {
        XCTAssertEqual(point1 * 2.0, point2)
        XCTAssertEqual(point3D1 * 2.0, point3D2)
    }
    
    func testScaleSize() {
        XCTAssertEqual(size1 * 2.0, size2)
        XCTAssertEqual(size3D1 * 2.0, size3D2)
    }
    
    func testScaleRect() {
        XCTAssertEqual(CGRect(origin: point1, size: size1) * 2.0, CGRect(origin: point2, size: size2))
        XCTAssertEqual(Cube3D(origin: point3D1, size: size3D1) * 2.0, Cube3D(origin: point3D2, size: size3D2))
    }
    
    func testRandomInt1() {
        let max = 2000
        let random = randomInt(limit: max)
        XCTAssert(random >= 0)
        XCTAssert(random <= max)
    }
    
    func testRandomInt2() {
        let min = 1000
        let max = 2000
        let random = randomInt(min: min, max: max)
        XCTAssert(random >= min)
        XCTAssert(random <= max)
    }

    func testRandomSize() {
        let min = CGFloat(1000)
        let max = CGFloat(2000)
        let random = randomSize(min: Int(min), max: Int(max))
        XCTAssert(random.width >= min)
        XCTAssert(random.height >= min)
        XCTAssert(random.width <= max)
        XCTAssert(random.height <= max)
    }

    func testRandomSize3D() {
        let min = CGFloat(1000)
        let max = CGFloat(2000)
        let random = randomSize3D(min: Int(min), max: Int(max))
        XCTAssert(random.width >= min)
        XCTAssert(random.height >= min)
        XCTAssert(random.depth >= min)
        XCTAssert(random.width <= max)
        XCTAssert(random.height <= max)
        XCTAssert(random.depth <= max)
    }
    
    func testRandomObject() {
        let array = ["one", "two", "three"]
        let random = array.randomObject()
        XCTAssert(array.contains(random))
    }
    
    func testRemoveObject() {
        var array = ["one", "two", "three"]
        array.removeObject(object: "two")
        XCTAssertEqual(array, ["one", "three"])
    }
    
    func testRoundTo() {
        XCTAssertEqual(17.37.roundTo(precision: 0.5), 17.5)
    }

    func testRoundDown() {
        XCTAssertEqual(17.37.roundDown(precision: 0.5), 17.0)
    }
    
    func testRectCenter() {
        XCTAssertEqual(CGRect(origin: .zero, size: size2).center(), point1)
        XCTAssertEqual(Cube3D(origin: Point3D.zero, size: size3D2).center(), point3D1)
    }
    
    func testJSON() {
        XCTAssert(point1.toJSON() == ["x": 10.0, "y": 10.0])
        XCTAssert(point3D1.toJSON() == ["x": 10, "y": 10, "z": 10.0])
        XCTAssert(size1.toJSON() == ["width": 10.0, "height": 10.0])
        XCTAssert(size3D1.toJSON() == ["depth": 10.0, "width": 10.0, "height": 10.0])
        XCTAssert(CGRect(origin: point1, size: size2).toJSON() ==  ["size": ["height": 20.0, "width": 20.0], "origin": ["y": 10.0, "x": 10.0]])
        XCTAssert(Cube3D(origin: point3D1, size: size3D2).toJSON() == ["origin": ["x": 10, "y": 10, "z": 10.0], "size": ["width": 20.0, "height": 20.0, "depth": 20.0]])
    }
    
    func testContains() {
        XCTAssert(Cube3D(origin: Point3D.zero, size: size3D2).contains(point: point3D1))
        XCTAssert(!Cube3D(origin: Point3D.zero, size: size3D1).contains(point: point3D2))
    }
    
    func test3DTo2D() {
        XCTAssertEqual(point3D1.toPoint(), point1)
        XCTAssertEqual(size3D1.toSize(), size1)
        XCTAssertEqual(Cube3D(origin: point3D1, size: size3D2).toRect(), CGRect(origin: point1, size: size2))
    }

    func testLength() {
        XCTAssertEqual(size1.length(), 14.142135623730951)
        XCTAssertEqual(size3D1.length(), 17.320508075688775)
    }
    
    func testRoundPoint() {
        XCTAssertEqual(CGPoint(x: 17.2, y: 14.3).roundTo(precision: 5.0), CGPoint(x: 15.0, y: 15.0))
        XCTAssertEqual(Point3D(x: CGFloat(17.2), y: CGFloat(14.3), z: CGFloat(11.9)).roundTo(precision: 5.0), Point3D(x: CGFloat(15.0), y: CGFloat(15.0), z: CGFloat(10.0)))
    }
    
    func testRadians() {
        XCTAssertEqual(radiansToDegrees(radians: Double.pi), 180)
        XCTAssertEqual(degreesToRadians(degrees: 180), Double.pi)
    }
    
    func testTimes() {
        var string = ""
        5.times {
            string += "foo"
        }
        XCTAssertEqual(string, "foofoofoofoofoo")
    }
    
    func testTitleCase() {
        XCTAssertEqual("flare is cool".titlecaseString(), "Flare Is Cool")
        XCTAssertEqual("FLARE IS COOL".titlecaseString(), "Flare Is Cool")
    }
    
    func testSerialization() {
        let dict = ["foo": "bar"]
        XCTAssert(dict.toData()!.toJSONDictionary()! == dict)
    }
    
    func testJSONString() {
        let dict = ["foo": "bar"]
        XCTAssertEqual(dict.toJSONString()!, "{\"foo\":\"bar\"}")
    }
    
    func textJSONGetters() {
        let dict: JSONDictionary = ["string": "foo", "int": 42, "double": 3.14159, "array": [1, 2, 3], "array2": ["foo", "bar"], "dictionary": ["foo": "bar"]]
        XCTAssertEqual(dict.getString(key: "string"), "foo")
        XCTAssertEqual(dict.getInt(key: "int"), 42)
        XCTAssertEqual(dict.getDouble(key: "double"), 3.14159)
        XCTAssert(dict.getArray(key: "array").description == [1, 2, 3].description)
        XCTAssertEqual(dict.getStringArray(key: "array2"), ["foo", "bar"])
        XCTAssert(dict.getDictionary(key: "dictionary") == ["foo": "bar"])
    }
}
