const express = require('express');
const { Server } = require('socket.io');
const http = require('http');
const cors = require('cors');

const BOARD_SIZE = 9;
const BLOCK_TYPES = new Set(['I', 'O', 'T', 'L', 'J', 'S', 'Z']);
const PLAYER_ROLES = ['player1', 'player2'];

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' },
});

const BLOCKS = {
  I: [
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }, { x: 3, y: 0 }],
    [{ x: 0, y: 0 }, { x: 0, y: 1 }, { x: 0, y: 2 }, { x: 0, y: 3 }],
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }, { x: 3, y: 0 }],
    [{ x: 0, y: 0 }, { x: 0, y: 1 }, { x: 0, y: 2 }, { x: 0, y: 3 }],
  ],
  O: [
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }],
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }],
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }],
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }],
  ],
  T: [
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }, { x: 1, y: 1 }],
    [{ x: 1, y: 0 }, { x: 1, y: 1 }, { x: 1, y: 2 }, { x: 0, y: 1 }],
    [{ x: 1, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }, { x: 2, y: 1 }],
    [{ x: 0, y: 0 }, { x: 0, y: 1 }, { x: 0, y: 2 }, { x: 1, y: 1 }],
  ],
  L: [
    [{ x: 0, y: 0 }, { x: 0, y: 1 }, { x: 0, y: 2 }, { x: 1, y: 2 }],
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }, { x: 0, y: 1 }],
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }, { x: 1, y: 2 }],
    [{ x: 2, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }, { x: 2, y: 1 }],
  ],
  J: [
    [{ x: 1, y: 0 }, { x: 1, y: 1 }, { x: 1, y: 2 }, { x: 0, y: 2 }],
    [{ x: 0, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }, { x: 2, y: 1 }],
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 0, y: 1 }, { x: 0, y: 2 }],
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }, { x: 2, y: 1 }],
  ],
  S: [
    [{ x: 1, y: 0 }, { x: 2, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }],
    [{ x: 0, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }, { x: 1, y: 2 }],
    [{ x: 1, y: 0 }, { x: 2, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }],
    [{ x: 0, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 1 }, { x: 1, y: 2 }],
  ],
  Z: [
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }, { x: 2, y: 1 }],
    [{ x: 1, y: 0 }, { x: 1, y: 1 }, { x: 0, y: 1 }, { x: 0, y: 2 }],
    [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }, { x: 2, y: 1 }],
    [{ x: 1, y: 0 }, { x: 1, y: 1 }, { x: 0, y: 1 }, { x: 0, y: 2 }],
  ],
};

const rooms = new Map();
const waitingQueue = [];

function createEmptyBoard() {
  return Array.from({ length: BOARD_SIZE }, () => Array(BOARD_SIZE).fill('empty'));
}

function publicRoom(room) {
  return {
    roomId: room.roomId,
    roomTitle: room.roomTitle,
    status: room.status,
    board: room.board,
    players: room.players,
    currentTurn: room.currentTurn,
    walls: room.walls,
    winner: room.winner,
    winReason: room.winReason,
    lastMove: room.lastMove,
    createdAt: room.createdAt,
    updatedAt: room.updatedAt,
  };
}

function waitingRoomList() {
  return Array.from(rooms.values())
    .filter((room) => room.status === 'waiting' && room.players.length === 1)
    .map((room) => {
      const host = room.players[0];
      return {
        id: room.roomId,
        room_title: room.roomTitle,
        host_user_id: host.userId,
        host_nickname: host.nickname,
        player_count: room.players.length,
      };
    });
}

function emitAvailableRooms() {
  io.emit('available_rooms', waitingRoomList());
}

function emitRoom(room) {
  room.updatedAt = Date.now();
  io.to(room.roomId).emit('room_state', publicRoom(room));
}

function emitError(socket, message, code = 'bad_request') {
  socket.emit('game_error', { code, message });
}

function normalizeRotation(rotation) {
  const raw = Number.isInteger(rotation) ? rotation : Number(rotation);
  if (!Number.isFinite(raw)) return 0;
  return ((raw % 4) + 4) % 4;
}

function getBlockCells(blockType, rotation, startX, startY) {
  return BLOCKS[blockType][normalizeRotation(rotation)].map((p) => ({
    x: startX + p.x,
    y: startY + p.y,
  }));
}

function canPlaceBlock(board, blockType, rotation, startX, startY) {
  if (!BLOCK_TYPES.has(blockType)) return false;
  const cells = getBlockCells(blockType, rotation, startX, startY);
  return cells.every((cell) => (
    cell.x >= 0 &&
    cell.x < BOARD_SIZE &&
    cell.y >= 0 &&
    cell.y < BOARD_SIZE &&
    board[cell.y][cell.x] === 'empty'
  ));
}

function hasValidMove(board, blockType) {
  if (!BLOCK_TYPES.has(blockType)) return false;
  for (let y = 0; y < BOARD_SIZE; y += 1) {
    for (let x = 0; x < BOARD_SIZE; x += 1) {
      for (let rotation = 0; rotation < 4; rotation += 1) {
        if (canPlaceBlock(board, blockType, rotation, x, y)) return true;
      }
    }
  }
  return false;
}

function addRandomWalls(room) {
  while (room.walls.length < 2) {
    const x = Math.floor(Math.random() * BOARD_SIZE);
    const y = Math.floor(Math.random() * BOARD_SIZE);
    if (room.board[y][x] !== 'empty') continue;
    room.board[y][x] = 'wall';
    room.walls.push({ x, y });
  }
}

function processExplosions(board) {
  const clearKeys = new Set();

  for (let y = 0; y < BOARD_SIZE; y += 1) {
    let lastWallX = -1;
    for (let x = 0; x < BOARD_SIZE; x += 1) {
      if (board[y][x] !== 'wall') continue;
      if (lastWallX !== -1 && x - lastWallX > 1) {
        let filled = true;
        for (let ix = lastWallX + 1; ix < x; ix += 1) {
          if (board[y][ix] === 'empty') filled = false;
        }
        if (filled) {
          for (let ix = lastWallX + 1; ix < x; ix += 1) {
            clearKeys.add(`${ix},${y}`);
          }
        }
      }
      lastWallX = x;
    }
  }

  for (let x = 0; x < BOARD_SIZE; x += 1) {
    let lastWallY = -1;
    for (let y = 0; y < BOARD_SIZE; y += 1) {
      if (board[y][x] !== 'wall') continue;
      if (lastWallY !== -1 && y - lastWallY > 1) {
        let filled = true;
        for (let iy = lastWallY + 1; iy < y; iy += 1) {
          if (board[iy][x] === 'empty') filled = false;
        }
        if (filled) {
          for (let iy = lastWallY + 1; iy < y; iy += 1) {
            clearKeys.add(`${x},${iy}`);
          }
        }
      }
      lastWallY = y;
    }
  }

  for (const key of clearKeys) {
    const [x, y] = key.split(',').map(Number);
    if (board[y][x] !== 'wall') board[y][x] = 'empty';
  }

  return Array.from(clearKeys).map((key) => {
    const [x, y] = key.split(',').map(Number);
    return { x, y };
  });
}

function createPlayer(socket, data, role) {
  return {
    socketId: socket.id,
    userId: String(data.userId || socket.id),
    nickname: String(data.nickname || 'Player'),
    role,
    selectedBlock: null,
    ready: false,
    connected: true,
  };
}

function createRoom(socket, data = {}, fromQueuePlayer = null) {
  const roomId = data.roomId || `room_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const host = fromQueuePlayer || createPlayer(socket, data, 'player1');
  const room = {
    roomId,
    roomTitle: String(data.roomTitle || `${host.nickname}'s room`),
    status: 'waiting',
    board: createEmptyBoard(),
    players: [host],
    currentTurn: 'player1',
    walls: [],
    winner: null,
    winReason: null,
    lastMove: null,
    createdAt: Date.now(),
    updatedAt: Date.now(),
  };
  rooms.set(roomId, room);
  socket.join(roomId);
  socket.emit('room_created', { roomId });
  emitRoom(room);
  emitAvailableRooms();
  return room;
}

function startSelecting(room) {
  if (room.players.length !== 2) return;
  room.status = 'selecting';
  room.players.forEach((player, index) => {
    player.role = PLAYER_ROLES[index];
    player.ready = false;
  });
  emitRoom(room);
  emitAvailableRooms();
}

function joinRoom(socket, data = {}) {
  const room = rooms.get(data.roomId);
  if (!room) return emitError(socket, '방을 찾을 수 없습니다.', 'room_not_found');

  const userId = String(data.userId || socket.id);
  const existing = room.players.find((player) => player.userId === userId);
  if (existing) {
    existing.socketId = socket.id;
    existing.connected = true;
    socket.join(room.roomId);
    emitRoom(room);
    return;
  }

  if (room.players.length >= 2 || room.status !== 'waiting') {
    return emitError(socket, '이미 시작된 방입니다.', 'room_unavailable');
  }

  room.players.push(createPlayer(socket, data, 'player2'));
  socket.join(room.roomId);
  startSelecting(room);
}

function removeFromQueue(socketId, userId) {
  const index = waitingQueue.findIndex((player) => (
    player.socketId === socketId || (userId && player.userId === userId)
  ));
  if (index !== -1) waitingQueue.splice(index, 1);
}

function finishRoom(room, winner, reason) {
  if (room.status === 'finished') return;
  room.status = 'finished';
  room.winner = winner;
  room.winReason = reason;
  emitRoom(room);
  saveResult(room).catch((error) => {
    console.error('Failed to save result:', error.message);
  });
}

async function saveResult(room) {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) return;

  const payload = {
    game_key: 'crush_block',
    room_id: room.roomId,
    winner_role: room.winner,
    win_reason: room.winReason,
    players: room.players.map((player) => ({
      user_id: player.userId,
      nickname: player.nickname,
      role: player.role,
      selected_block: player.selectedBlock,
    })),
    finished_at: new Date().toISOString(),
  };

  const response = await fetch(`${url}/rest/v1/multiplayer_match_results`, {
    method: 'POST',
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error(`Supabase REST ${response.status}: ${await response.text()}`);
  }
}

io.on('connection', (socket) => {
  socket.on('list_rooms', () => {
    socket.emit('available_rooms', waitingRoomList());
  });

  socket.on('create_room', (data) => {
    removeFromQueue(socket.id, data?.userId);
    createRoom(socket, data || {});
  });

  socket.on('join_room', (data) => {
    removeFromQueue(socket.id, data?.userId);
    joinRoom(socket, data || {});
  });

  socket.on('join_queue', (data = {}) => {
    removeFromQueue(socket.id, data.userId);
    const player = createPlayer(socket, data, 'player1');
    waitingQueue.push(player);

    if (waitingQueue.length < 2) {
      socket.emit('queue_state', { waiting: true });
      return;
    }

    const first = waitingQueue.shift();
    const second = waitingQueue.shift();
    const firstSocket = io.sockets.sockets.get(first.socketId);
    const secondSocket = io.sockets.sockets.get(second.socketId);
    if (!firstSocket || !secondSocket) return;

    const room = createRoom(firstSocket, {
      userId: first.userId,
      nickname: first.nickname,
      roomTitle: 'Quick Match',
    }, first);
    room.players.push({ ...second, role: 'player2' });
    secondSocket.join(room.roomId);
    startSelecting(room);
  });

  socket.on('select_block', (data = {}) => {
    const room = rooms.get(data.roomId);
    if (!room || room.status !== 'selecting') return;

    const player = room.players.find((p) => p.socketId === socket.id);
    if (!player) return emitError(socket, '플레이어를 찾을 수 없습니다.', 'not_in_room');
    if (!BLOCK_TYPES.has(data.blockType)) return emitError(socket, '지원하지 않는 블록입니다.', 'invalid_block');

    player.selectedBlock = data.blockType;
    player.ready = true;

    if (room.players.every((p) => p.ready && p.selectedBlock)) {
      room.status = 'playing';
      room.board = createEmptyBoard();
      room.walls = [];
      room.currentTurn = 'player1';
      addRandomWalls(room);

      const current = room.players.find((p) => p.role === room.currentTurn);
      if (!hasValidMove(room.board, current.selectedBlock)) {
        finishRoom(room, 'player2', 'no_valid_move');
        return;
      }
    }

    emitRoom(room);
  });

  socket.on('set_ready', (data = {}) => {
    const room = rooms.get(data.roomId);
    if (!room || room.status !== 'selecting') return;
    const player = room.players.find((p) => p.socketId === socket.id);
    if (!player) return;
    player.ready = Boolean(data.ready) && Boolean(player.selectedBlock);
    emitRoom(room);
  });

  socket.on('place_block', (data = {}) => {
    const room = rooms.get(data.roomId);
    if (!room || room.status !== 'playing') return;

    const player = room.players.find((p) => p.socketId === socket.id);
    if (!player) return emitError(socket, '플레이어를 찾을 수 없습니다.', 'not_in_room');
    if (player.role !== room.currentTurn) return emitError(socket, '현재 턴이 아닙니다.', 'not_your_turn');
    if (!player.selectedBlock) return emitError(socket, '블록을 먼저 선택해야 합니다.', 'block_not_selected');

    const x = Number(data.x);
    const y = Number(data.y);
    const rotation = normalizeRotation(data.rotation);
    if (!Number.isInteger(x) || !Number.isInteger(y)) {
      return emitError(socket, '좌표가 올바르지 않습니다.', 'invalid_position');
    }

    if (!canPlaceBlock(room.board, player.selectedBlock, rotation, x, y)) {
      return emitError(socket, '해당 위치에는 블록을 놓을 수 없습니다.', 'invalid_move');
    }

    const placedCells = getBlockCells(player.selectedBlock, rotation, x, y);
    placedCells.forEach((cell) => {
      room.board[cell.y][cell.x] = player.role;
    });

    const clearedCells = processExplosions(room.board);
    const exploded = clearedCells.length > 0;
    if (!exploded) {
      room.currentTurn = room.currentTurn === 'player1' ? 'player2' : 'player1';
    }

    room.lastMove = {
      player: player.role,
      blockType: player.selectedBlock,
      x,
      y,
      rotation,
      exploded,
      placedCells,
      clearedCells,
    };

    const turnPlayer = room.players.find((p) => p.role === room.currentTurn);
    if (turnPlayer && !hasValidMove(room.board, turnPlayer.selectedBlock)) {
      const winner = turnPlayer.role === 'player1' ? 'player2' : 'player1';
      finishRoom(room, winner, 'no_valid_move');
      return;
    }

    emitRoom(room);
  });

  socket.on('leave_room', (data = {}) => {
    removeFromQueue(socket.id, data.userId);
    const room = rooms.get(data.roomId);
    if (!room) return;
    const player = room.players.find((p) => p.socketId === socket.id || p.userId === data.userId);
    if (!player) return;
    socket.leave(room.roomId);
    if (room.status === 'waiting') {
      rooms.delete(room.roomId);
      emitAvailableRooms();
      return;
    }
    const opponent = room.players.find((p) => p.role !== player.role);
    finishRoom(room, opponent?.role || null, 'forfeit');
  });

  socket.on('reconnect_room', (data = {}) => {
    const room = rooms.get(data.roomId);
    if (!room) return emitError(socket, '방을 찾을 수 없습니다.', 'room_not_found');
    const player = room.players.find((p) => p.userId === data.userId);
    if (!player) return emitError(socket, '플레이어를 찾을 수 없습니다.', 'not_in_room');
    player.socketId = socket.id;
    player.connected = true;
    socket.join(room.roomId);
    emitRoom(room);
  });

  socket.on('disconnect', () => {
    const queued = waitingQueue.find((p) => p.socketId === socket.id);
    removeFromQueue(socket.id, queued?.userId);

    for (const room of rooms.values()) {
      const player = room.players.find((p) => p.socketId === socket.id);
      if (!player || room.status === 'finished') continue;
      player.connected = false;
      emitRoom(room);
    }
  });
});

app.get('/health', (_, res) => {
  res.json({ ok: true, rooms: rooms.size, waiting: waitingQueue.length });
});

app.get('/rooms', (_, res) => {
  res.json(waitingRoomList());
});

const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`Crush Block server running on port ${PORT}`);
});

module.exports = {
  BLOCKS,
  createEmptyBoard,
  canPlaceBlock,
  hasValidMove,
  processExplosions,
};
