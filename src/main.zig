const std = @import("std");
const dp = std.debug.print;
const defrng = std.rand.DefaultPrng;
const ray = @cImport({
    @cInclude("raylib.h");
});

const BACKGROUND_COLOR = ray.Color{ .r = 30, .g = 30, .b = 30, .a = 255 };

const BORDER_THICKNESS: f32 = 1.5;
const BORDER_COLOR = ray.Color{ .r = 105, .g = 105, .b = 105, .a = 255 };
const GRID_ROW = 45;
const GRID_COL = 45;
const ALIVE_COLOR = ray.Color{ .r = 153, .g = 153, .b = 153, .a = 255 };
const DEAD_COLOR = BACKGROUND_COLOR;

const Cell = enum(u8) {
    Alive,
    Dead,
};

const Gol = struct {
    cells: [GRID_ROW][GRID_COL]Cell,
    cellSize: ray.Vector2,
    pause: bool,
    borders: ray.Rectangle,

    fn new(bounds: ray.Rectangle) Gol {
        var this = Gol{
            .cells = undefined,
            .cellSize = undefined,
            .pause = true,
            .borders = bounds,
        };
        updateCellSize(&this);
        resetGrid(&this);
        return this;
    }

    fn updateBounds(self: *Gol) void {
        self.borders.width = @intToFloat(f32, ray.GetScreenWidth());
        self.borders.height = @intToFloat(f32, ray.GetScreenHeight());
    }

    fn updateCellSize(self: *Gol) void {
        self.cellSize = ray.Vector2{ .x = (self.borders.x + self.borders.width) / @floatCast(f32, GRID_COL), .y = (self.borders.y + self.borders.height) / @floatCast(f32, GRID_ROW) };
    }

    fn randomize(self: *Gol, chance: f32) void {
        var rng: defrng = defrng.init(0);
        for (0..GRID_ROW) |row| {
            for (0..GRID_COL) |col| {
                if (rng.random().float(f32) <= chance) {
                    self.cells[row][col] = Cell.Alive;
                } else {
                    self.cells[row][col] = Cell.Dead;
                }
            }
        }
    }

    fn resetGrid(self: *Gol) void {
        for (0..GRID_ROW) |row| {
            for (0..GRID_COL) |col| {
                self.cells[row][col] = Cell.Dead;
            }
        }
    }
};

fn isInGrid(row: i32, col: i32) bool {
    return (row >= 0 and row < GRID_ROW) and (col >= 0 and col < GRID_COL);
}

fn countNeighbors(cells: *[GRID_ROW][GRID_COL]Cell, row: i32, col: i32) i32 {
    var neighbors: i32 = 0;
    var dr: i32 = -1;
    var dc: i32 = -1;
    while (dr <= 1) : (dr += 1) {
        while (dc <= 1) : (dc += 1) {
            if (dr == 0 and dc == 0) {
                continue;
            }
            const newRow = row + dr;
            const newCol = col + dc;
            if (isInGrid(newRow, newCol) and cells[@intCast(usize, newRow)][@intCast(usize, newCol)] == Cell.Alive) {
                neighbors += 1;
            }
        }
        dc = -1;
    }
    return neighbors;
}

fn drawGrid(gol: *const Gol) void {
    var r: usize = 0;
    var c: usize = 0;
    while (r < GRID_ROW) : (r += 1) {
        while (c < GRID_COL) : (c += 1) {
            var currentColor: ray.Color = undefined;
            const currX = (@intToFloat(f32, c) * gol.cellSize.x) + gol.borders.x;
            const currY = (@intToFloat(f32, r) * gol.cellSize.y) + gol.borders.y;
            if (gol.cells[r][c] == Cell.Alive) {
                currentColor = ALIVE_COLOR;
            } else {
                currentColor = DEAD_COLOR;
            }
            ray.DrawRectangleV(ray.Vector2{ .x = currX, .y = currY }, gol.cellSize, currentColor);
        }
        c = 0;
    }

    r = 0;
    while (r < GRID_ROW) : (r += 1) {
        const y = (@intToFloat(f32, r) * gol.cellSize.y) + gol.borders.y;
        ray.DrawLineEx(ray.Vector2{ .x = gol.borders.x, .y = y }, ray.Vector2{ .x = gol.borders.x + gol.borders.width, .y = y }, BORDER_THICKNESS, BORDER_COLOR);
    }

    c = 0;
    while (c < GRID_COL) : (c += 1) {
        const x = (@intToFloat(f32, c) * gol.cellSize.x) + gol.borders.x;
        ray.DrawLineEx(ray.Vector2{ .x = x, .y = gol.borders.y }, ray.Vector2{ .x = x, .y = gol.borders.y + gol.borders.height }, BORDER_THICKNESS, BORDER_COLOR);
    }
}

fn restart() void {
    dp("Do something in the restart function", .{});
}

fn isMouseInGrid(pos: ray.Vector2, rect: ray.Rectangle) bool {
    return (pos.x >= rect.x and pos.x <= rect.x + rect.width) and
        (pos.y >= rect.y and pos.y <= rect.y + rect.height);
}

fn drawPausedSign(x: f32, y: f32) void {
    const rectSize = ray.Vector2 {.x = 15, .y = 60};
    ray.DrawRectangleV(
        ray.Vector2{.x = x, .y = y},
        rectSize,
        ray.BEIGE
    );
    ray.DrawRectangleV(
        ray.Vector2{.x = x + 30, .y = y},
        rectSize,
        ray.BEIGE
    );
}

const InputActions = enum {
    Click,
    Clear,
    Pause,
    Restart,
    Nothing,
};

fn handle_input() InputActions {
    if (ray.IsKeyPressed(ray.KEY_R)) {
        return InputActions.Restart;
    } else if (ray.IsKeyPressed(ray.KEY_C)) {
        return InputActions.Clear;
    } else if (ray.IsKeyPressed(ray.KEY_SPACE)) {
        return InputActions.Pause;
    } else if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
        return InputActions.Click;
    }
    return InputActions.Nothing;
}

fn update_paused(gol: *Gol, isClicked: bool) void {
    if (!isClicked) {
        return;
    }
    const mousePos = ray.GetMousePosition();
    if (!isMouseInGrid(mousePos, gol.borders)) {
        return;
    }
    const col = @floatToInt(usize, (mousePos.x - gol.borders.x) / gol.cellSize.x);
    const row = @floatToInt(usize, (mousePos.y - gol.borders.y) / gol.cellSize.y);
    if (gol.cells[row][col] == Cell.Alive) {
        gol.cells[row][col] = Cell.Dead;
    } else {
        gol.cells[row][col] = Cell.Alive;
    }
}

fn update_unpaused(current: *Gol, next: *Gol) void {
    next.cells = current.cells;
    for (0..GRID_ROW) |row| {
        for (0..GRID_COL) |col| {
            const neighbors = countNeighbors(&current.cells, @intCast(i32, row), @intCast(i32, col));
            if (current.cells[row][col] == Cell.Alive) {
                if (neighbors <= 1 or neighbors >= 4) {
                    // Death by solitude and overpopulation, respectively
                    next.cells[row][col] = Cell.Dead;
                }
            } else {
                if (neighbors == 3) {
                    // Becomes alive
                    next.cells[row][col] = Cell.Alive;
                }
            }
        }
    }
    // const temp = current.*;
    current.cells = next.cells;
    // next.* = temp;
    // next.resetGrid();
}

fn render(gol: *const Gol) void {
    drawGrid(gol);
    if (gol.pause) {
        drawPausedSign(50, 50);
    }
}

pub fn main() void {
    ray.SetConfigFlags(ray.FLAG_WINDOW_MAXIMIZED | ray.FLAG_WINDOW_RESIZABLE | ray.FLAG_MSAA_4X_HINT);
    ray.InitWindow(900, 600, "Zig Automaton");
    ray.SetTargetFPS(60);

    const currentBounds = ray.Rectangle{
        .x = 0,
        .y = 0,
        .width = @intToFloat(f32, ray.GetScreenWidth()) / 2,
        .height = @intToFloat(f32, ray.GetScreenHeight()),
    };
    var current: Gol = Gol.new(currentBounds);
    var next: Gol = Gol.new(currentBounds);

    while (!ray.WindowShouldClose()) {
        const action = handle_input();
        var clicked: bool = false;
        switch (action) {
            InputActions.Click => clicked = true,
            InputActions.Clear => current.resetGrid(),
            InputActions.Pause => current.pause = !current.pause,
            InputActions.Restart => restart(),
            InputActions.Nothing => {},
        }

        if (ray.IsWindowResized()) {
            current.updateBounds();
            current.updateCellSize();
        }

        if (!current.pause) {
            update_unpaused(&current, &next);
            // current.pause = true;
        } else {
            update_paused(&current, clicked);
        }
        ray.BeginDrawing();
        {
            ray.ClearBackground(BACKGROUND_COLOR);
            render(&current);
        }
        ray.EndDrawing();
    }
}
