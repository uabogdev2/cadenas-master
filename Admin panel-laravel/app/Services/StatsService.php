<?php

namespace App\Services;

use App\Models\Battle;
use App\Models\Level;
use App\Models\User;
use App\Models\UserProgress;
use Illuminate\Support\Collection;

class StatsService
{
    public function getKpis(): array
    {
        return [
            'totalUsers' => User::count(),
            'activeUsers' => User::where('completedLevels', '>', 0)->count(),
            'totalLevels' => Level::count(),
            'totalBattles' => Battle::count(),
            'activeBattles' => Battle::where('status', 'active')->count(),
        ];
    }

    public function getPointStats(): array
    {
        $row = User::selectRaw('SUM(points) as total, AVG(points) as average, MAX(points) as max, MIN(points) as min')->first();

        return [
            'total' => (int) ($row->total ?? 0),
            'average' => (int) ($row->average ?? 0),
            'max' => (int) ($row->max ?? 0),
            'min' => (int) ($row->min ?? 0),
        ];
    }

    public function getCompletedLevelsStats(): array
    {
        $row = User::selectRaw('SUM(completedLevels) as total, AVG(completedLevels) as average, MAX(completedLevels) as max, MIN(completedLevels) as min')->first();

        return [
            'total' => (int) ($row->total ?? 0),
            'average' => (int) ($row->average ?? 0),
            'max' => (int) ($row->max ?? 0),
            'min' => (int) ($row->min ?? 0),
        ];
    }

    public function getTopUsersByPoints(int $limit = 10): Collection
    {
        return User::query()
            ->orderByDesc('points')
            ->limit($limit)
            ->get(['id', 'displayName', 'email', 'points']);
    }

    public function getTopUsersByCompletedLevels(int $limit = 10): Collection
    {
        return User::query()
            ->orderByDesc('completedLevels')
            ->limit($limit)
            ->get(['id', 'displayName', 'email', 'completedLevels']);
    }

    public function getLevelsOptions(): Collection
    {
        return Level::query()
            ->orderBy('name')
            ->get(['id', 'name'])
            ->mapWithKeys(fn (Level $level) => [$level->id => "{$level->id} - {$level->name}"]);
    }

    public function getLevelAnalysis(?int $levelId = null): array
    {
        $query = UserProgress::query();

        if ($levelId) {
            $query->where('levelId', $levelId);
        }

        $completedCount = (clone $query)->where('isCompleted', true)->count();
        $totalAttempts = (clone $query)->sum('attempts');
        $bestTime = (clone $query)->whereNotNull('bestTime')->min('bestTime');
        $avgTime = (clone $query)->whereNotNull('bestTime')->avg('bestTime');

        return [
            'levelId' => $levelId,
            'completedCount' => $completedCount,
            'totalAttempts' => $totalAttempts,
            'bestTime' => $bestTime ? (int) $bestTime : null,
            'avgTime' => $avgTime ? (int) round($avgTime) : null,
        ];
    }
}

