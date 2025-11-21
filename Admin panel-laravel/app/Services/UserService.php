<?php

namespace App\Services;

use App\Models\UnlockedHint;
use App\Models\User;
use App\Models\UserProgress;
use App\Models\UserStats;
use Illuminate\Support\Facades\DB;

class UserService
{
    public function adjustPoints(User $user, int $delta): User
    {
        return DB::transaction(function () use ($user, $delta) {
            $user->points = $this->clampPoints($user->points + $delta);
            $user->save();

            return $user->refresh();
        });
    }

    public function adjustTrophies(User $user, int $delta): User
    {
        return DB::transaction(function () use ($user, $delta) {
            $user->trophies = $this->normalizeTrophies($user->trophies + $delta);
            $user->save();

            return $user->refresh();
        });
    }

    public function resetUser(User $user): User
    {
        return DB::transaction(function () use ($user) {
            UserProgress::where('userId', $user->id)->delete();
            UnlockedHint::where('userId', $user->id)->delete();

            UserStats::updateOrCreate(
                ['userId' => $user->id],
                [
                    'totalAttempts' => 0,
                    'totalPlayTime' => 0,
                    'bestTimes' => [],
                ],
            );

            $user->points = User::DEFAULT_POINTS;
            $user->trophies = User::DEFAULT_TROPHIES;
            $user->completedLevels = 0;
            $user->save();

            return $user->refresh();
        });
    }

    public function normalizeTrophies(int $value): int
    {
        $value = max(0, $value);

        if ($value >= 10 && $value <= 90) {
            return 0;
        }

        return $value;
    }

    private function clampPoints(int $value): int
    {
        return max(0, $value);
    }
}

