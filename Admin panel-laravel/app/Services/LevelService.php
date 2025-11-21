<?php

namespace App\Services;

use App\Models\Level;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\File;

class LevelService
{
    public function importFromArray(array $levels): void
    {
        $now = now();

        $payload = collect($levels)->map(function (array $level) use ($now): array {
            $level['codeLength'] = $level['codeLength'] ?? strlen((string) ($level['code'] ?? ''));
            $level['createdAt'] = $level['createdAt'] ?? $now;
            $level['updatedAt'] = $level['updatedAt'] ?? $now;
            $level['additionalHints'] = json_encode($level['additionalHints'] ?? [], JSON_UNESCAPED_UNICODE);

            return Arr::only($level, [
                'id',
                'name',
                'instruction',
                'code',
                'codeLength',
                'pointsReward',
                'isLocked',
                'timeLimit',
                'additionalHints',
                'hintCost',
                'createdAt',
                'updatedAt',
            ]);
        })->all();

        if (empty($payload)) {
            return;
        }

        Level::upsert(
            $payload,
            ['id'],
            [
                'name',
                'instruction',
                'code',
                'codeLength',
                'pointsReward',
                'isLocked',
                'timeLimit',
                'additionalHints',
                'hintCost',
                'updatedAt',
            ],
        );
    }

    public function importFromJsonFile(string $path): void
    {
        if (! File::exists($path)) {
            throw new \RuntimeException("Levels JSON introuvable: {$path}");
        }

        $decoded = json_decode(File::get($path), true, flags: JSON_THROW_ON_ERROR);

        if (! is_array($decoded)) {
            throw new \RuntimeException('Le fichier JSON des niveaux est invalide.');
        }

        $this->importFromArray($decoded);
    }

    public function resetFromSeed(): void
    {
        $seedPath = config('lockgame.levels.seed_path');
        $this->importFromJsonFile($seedPath);
    }

    public function exportToPath(?string $targetPath = null): string
    {
        $targetPath ??= config('lockgame.levels.export_path');

        File::ensureDirectoryExists(dirname($targetPath));
        File::put($targetPath, $this->exportAsJsonString());

        return $targetPath;
    }

    public function exportAsJsonString(): string
    {
        return json_encode($this->getLevelsPayload(), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    }

    public function getLevelsPayload(): Collection
    {
        return Level::query()
            ->orderBy('id')
            ->get([
                'id',
                'name',
                'instruction',
                'code',
                'codeLength',
                'pointsReward',
                'isLocked',
                'timeLimit',
                'additionalHints',
                'hintCost',
            ])
            ->map(function (Level $level): array {
                return [
                    'id' => $level->id,
                    'name' => $level->name,
                    'instruction' => $level->instruction,
                    'code' => $level->code,
                    'codeLength' => $level->codeLength,
                    'pointsReward' => $level->pointsReward,
                    'isLocked' => $level->isLocked,
                    'timeLimit' => $level->timeLimit,
                    'additionalHints' => $level->additionalHints ?? [],
                    'hintCost' => $level->hintCost,
                ];
            });
    }
}

