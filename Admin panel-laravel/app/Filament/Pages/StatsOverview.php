<?php

namespace App\Filament\Pages;

use App\Services\StatsService;
use Filament\Pages\Page;
use BackedEnum;
use UnitEnum;

class StatsOverview extends Page
{
    protected static BackedEnum|string|null $navigationIcon = 'heroicon-o-chart-bar';

    protected static UnitEnum|string|null $navigationGroup = 'Analytique';

    protected string $view = 'filament.pages.stats-overview';

    public ?int $selectedLevelId = null;

    public function updatedSelectedLevelId($value): void
    {
        $this->selectedLevelId = $value ? (int) $value : null;
    }

    protected function getViewData(): array
    {
        $service = app(StatsService::class);

        return [
            'kpis' => $service->getKpis(),
            'points' => $service->getPointStats(),
            'completedLevels' => $service->getCompletedLevelsStats(),
            'topPoints' => $service->getTopUsersByPoints(),
            'topLevels' => $service->getTopUsersByCompletedLevels(),
            'levelsOptions' => $service->getLevelsOptions(),
            'levelAnalysis' => $service->getLevelAnalysis($this->selectedLevelId),
            'selectedLevelId' => $this->selectedLevelId,
        ];
    }

    public static function canAccess(): bool
    {
        return auth()->user()?->canViewStats() ?? false;
    }

    public static function shouldRegisterNavigation(): bool
    {
        return self::canAccess();
    }
}

