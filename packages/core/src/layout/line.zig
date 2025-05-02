pub fn Line(comptime T: type) type {
    return struct {
        start: T,
        end: T,
        // A function to create a new Line

        pub fn new(start: T, end: T) Line {
            return Line{ .start = start, .end = end };
        }
    };
}

pub fn new(T: type, start: anytype, end: anytype) Line(T) {
    return Line(T){ .start = start, .end = end };
}

pub const FALSE: Line(bool) = new(bool, false, false);
