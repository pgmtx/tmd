const std = @import("std");

pub fn List(comptime Value: type) type {
    return struct {
        // size is 3 words.
        //info: ?struct {
        //    head: *Element(Value),
        //    tail: *Element(Value),
        //} = null,

        // size is 2 words.
        head: ?*Element(Value) = null,
        tail: ?*Element(Value) = null,

        const Self = @This();

        pub fn empty(self: *const Self) bool {
            std.debug.assert((self.head == null) == (self.tail == null));
            return self.head == null;
        }

        // e must not be in any list.
        pub fn push(self: *Self, e: *Element(Value)) void {
            if (self.tail) |tail| {
                tail.next = e;
                e.prev = tail;
                self.tail = e;
            } else {
                self.head = e;
                self.tail = e;
                e.prev = null;
            }
            e.next = null;
        }

        // ToDo: renamed tp popTail/pushTail
        pub fn pop(self: *Self) ?*Element(Value) {
            if (self.tail) |tail| {
                if (tail.prev) |prev| {
                    prev.next = null;
                    self.tail = prev;
                } else {
                    self.head = null;
                    self.tail = null;
                }
                return tail;
            }

            return null;
        }

        // e must not be in any list.
        pub fn pushHead(self: *Self, e: *Element(Value)) void {
            if (self.head) |head| {
                head.prev = e;
                e.next = head;
                self.head = e;
            } else {
                self.head = e;
                self.tail = e;
                e.next = null;
            }
            e.prev = null;
        }

        pub fn popHead(self: *Self) ?*Element(Value) {
            if (self.head) |head| {
                if (head.next) |next| {
                    next.prev = null;
                    self.head = next;
                } else {
                    self.head = null;
                    self.tail = null;
                }
                return head;
            }

            return null;
        }

        pub fn delete(self: *Self, e: *Element(Value)) void {
            if (self.head) |head| {
                if (e == head) {
                    _ = self.popHead();
                    return;
                }
                if (e == self.tail) {
                    _ = self.pop();
                    return;
                }
                e.prev.?.next = e.next;
                e.next.?.prev = e.prev;
            } else unreachable;
        }

        pub fn iterate(self: *Self, comptime f: fn (Value) void) void {
            if (self.head) |head| {
                var element = head;
                while (true) {
                    const next = element.next;
                    f(element.value);
                    if (next) |n| element = n else break;
                }
            }
        }
    };
}

pub fn Element(comptime Value: type) type {
    return struct {
        value: Value = undefined,
        prev: ?*Element(Value) = null,
        next: ?*Element(Value) = null,
    };
}

pub fn createListElement(comptime Node: type, allocator: std.mem.Allocator) !*Element(Node) {
    return try allocator.create(Element(Node));
}

pub fn destroyListElements(comptime NodeValue: type, l: List(NodeValue), comptime onNodeValue: ?fn (*NodeValue, std.mem.Allocator) void, allocator: std.mem.Allocator) void {
    var element = l.head;
    if (onNodeValue) |f| {
        while (element) |e| {
            const next = e.next;
            f(&e.value, allocator);
            allocator.destroy(e);
            element = next;
        }
    } else while (element) |e| {
        const next = e.next;
        allocator.destroy(e);
        element = next;
    }
}
