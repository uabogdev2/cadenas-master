<?php

namespace App\Services;

use App\Models\Battle;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class BattleService
{
    public function __construct(
        private readonly UserService $userService,
    ) {
    }

    public function forceFinish(Battle $battle): Battle
    {
        return DB::transaction(function () use ($battle) {
            if ($battle->status === 'finished') {
                return $battle;
            }

            $battle->loadMissing(['playerOne', 'playerTwo']);

            $result = $this->resolveResult($battle);

            $battle->status = 'finished';
            $battle->result = $result['result'];
            $battle->winner = $result['winner'];
            $battle->endTime = now();

            $battle->trophyChanges = $this->applyTrophyChanges($battle, $result['winnerKey']);
            $battle->save();

            return $battle->refresh();
        });
    }

    public function cleanupOldBattles(): array
    {
        $waitingTtl = config('lockgame.battles.waiting_ttl_minutes', 5);
        $finishedTtl = config('lockgame.battles.finished_ttl_minutes', 60);

        $waitingCutoff = Carbon::now()->subMinutes($waitingTtl);
        $finishedCutoff = Carbon::now()->subMinutes($finishedTtl);

        $waitingDeleted = Battle::query()
            ->where('status', 'waiting')
            ->where('createdAt', '<', $waitingCutoff)
            ->delete();

        $finishedDeleted = Battle::query()
            ->where('status', 'finished')
            ->where('updatedAt', '<', $finishedCutoff)
            ->delete();

        return [
            'waiting' => $waitingDeleted,
            'finished' => $finishedDeleted,
        ];
    }

    protected function resolveResult(Battle $battle): array
    {
        $player1Score = $battle->player1Score ?? 0;
        $player2Score = $battle->player2Score ?? 0;

        if ($player1Score > $player2Score) {
            return [
                'result' => 'player1_win',
                'winner' => $battle->player1,
                'winnerKey' => 'player1',
            ];
        }

        if ($player2Score > $player1Score) {
            return [
                'result' => 'player2_win',
                'winner' => $battle->player2,
                'winnerKey' => 'player2',
            ];
        }

        return [
            'result' => 'draw',
            'winner' => null,
            'winnerKey' => null,
        ];
    }

    protected function applyTrophyChanges(Battle $battle, ?string $winnerKey): array
    {
        $changes = [
            'player1' => 0,
            'player2' => 0,
        ];

        if ($winnerKey === 'player1') {
            $changes['player1'] = 100;
            $changes['player2'] = -100;
        } elseif ($winnerKey === 'player2') {
            $changes['player1'] = -100;
            $changes['player2'] = 100;
        }

        $this->applyTrophyDelta($battle->player1, $changes['player1']);
        $this->applyTrophyDelta($battle->player2, $changes['player2']);

        return $changes;
    }

    protected function applyTrophyDelta(?string $userId, int $delta): void
    {
        if ($delta === 0 || empty($userId)) {
            return;
        }

        $user = User::query()->lockForUpdate()->find($userId);

        if (! $user) {
            return;
        }

        $this->userService->adjustTrophies($user, $delta);
    }
}

