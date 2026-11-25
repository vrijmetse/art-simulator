import type { GameState } from '../core/types';
import { loadState, saveState, resetState } from '../core/save';

let currentState: GameState = loadState();

export function getState(): GameState {
  return currentState;
}

export function updateState(next: GameState): GameState {
  currentState = next;
  saveState(currentState);
  return currentState;
}

export function resetGameState(): GameState {
  currentState = resetState();
  return currentState;
}
