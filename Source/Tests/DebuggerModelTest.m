/*
 * MacGDBp
 * Copyright (c) 2015, Blue Static <https://www.bluestatic.org>
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
 */

#import <XCTest/XCTest.h>

#import "DebuggerModel.h"
#import "StackFrame.h"

@interface DebuggerModelTest : XCTestCase

@end

@implementation DebuggerModelTest {
  DebuggerModel* _model;
}

- (void)setUp {
  [super setUp];
  _model = [[DebuggerModel alloc] init];
}

- (void)tearDown {
  [_model release];
  [super tearDown];
}

- (NSMutableArray<StackFrame*>*)mutableStack {
  return (NSMutableArray<StackFrame*>*)_model.stack;
}

- (StackFrame*)makeStackFrameForFile:(NSString*)file
                              atLine:(NSUInteger)line
                          stackIndex:(NSUInteger)index {
  StackFrame* frame = [[[StackFrame alloc] init] autorelease];
  frame.filename = file;
  frame.lineNumber = line;
  frame.index = index;
  return frame;
}

- (NSArray<StackFrame*>*)initialStack {
  NSArray<StackFrame*>* initialStack = @[
    [self makeStackFrameForFile:@"/top/frame" atLine:12 stackIndex:0],
    [self makeStackFrameForFile:@"/middle/frame" atLine:44 stackIndex:1],
    [self makeStackFrameForFile:@"/bottom/frame" atLine:1 stackIndex:2]
  ];
  initialStack[0].loaded = YES;
  initialStack[1].loaded = YES;
  initialStack[2].loaded = YES;
  return initialStack;
}

- (void)testEmptyStackReplace {
  XCTAssertEqual(0u, _model.stackDepth);
  NSArray* stack = [self initialStack];
  [_model updateStack:stack];
  XCTAssertEqual(3u, _model.stackDepth);
  XCTAssertEqualObjects(stack, _model.stack);
}

- (void)testReplaceTopFrame {
  NSArray<StackFrame*>* initialStack = [self initialStack];
  [[self mutableStack] addObjectsFromArray:initialStack];
  XCTAssertEqual(3u, _model.stackDepth);

  NSArray<StackFrame*>* replacementStack = @[
    [self makeStackFrameForFile:@"/top/frame" atLine:999 stackIndex:0],
    initialStack[1],
    initialStack[2]
  ];
  [_model updateStack:replacementStack];
  XCTAssertEqualObjects(replacementStack, _model.stack);
  XCTAssertFalse(_model.stack[0].loaded);
  XCTAssertEqual(0u, _model.stack[0].index);
  XCTAssertTrue(_model.stack[1].loaded);
  XCTAssertEqual(1u, _model.stack[1].index);
  XCTAssertTrue(_model.stack[2].loaded);
  XCTAssertEqual(2u, _model.stack[2].index);
}

- (void)testAddNewTopFrame {
  [_model updateStack:[self initialStack]];
  XCTAssertEqual(3u, _model.stackDepth);

  NSMutableArray<StackFrame*>* replacementStack = [NSMutableArray arrayWithArray:[self initialStack]];
  [replacementStack insertObject:[self makeStackFrameForFile:@"/top/new" atLine:44 stackIndex:0]
                         atIndex:0];
  replacementStack[1].index = 1;
  replacementStack[2].index = 2;
  replacementStack[3].index = 3;

  [_model updateStack:replacementStack];
  XCTAssertEqual(4u, _model.stackDepth);
  XCTAssertEqualObjects(replacementStack, _model.stack);
  XCTAssertFalse(_model.stack[0].loaded);
  XCTAssertEqual(0u, _model.stack[0].index);
  XCTAssertTrue(_model.stack[1].loaded);
  XCTAssertEqual(1u, _model.stack[1].index);
  XCTAssertTrue(_model.stack[2].loaded);
  XCTAssertEqual(2u, _model.stack[2].index);
}

- (void)testRemoveTopFrame {
  NSArray* initialStack = [self initialStack];
  [_model updateStack:initialStack];
  XCTAssertEqual(3u, _model.stackDepth);

  [_model updateStack:[initialStack subarrayWithRange:NSMakeRange(1, 2)]];
  XCTAssertEqual(2u, _model.stackDepth);
  XCTAssertTrue(_model.stack[0].loaded);
  XCTAssertEqual(0u, _model.stack[0].index);
  XCTAssertTrue(_model.stack[1].loaded);
  XCTAssertEqual(1u, _model.stack[1].index);
}

- (void)testClearStack {
  [_model updateStack:[self initialStack]];
  XCTAssertEqual(3u, _model.stackDepth);
  [_model updateStack:@[]];
  XCTAssertEqual(0u, _model.stackDepth);
}

@end
