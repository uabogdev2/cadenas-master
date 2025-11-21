<?php

namespace App\Filament\Widgets;

use App\Services\StatsService;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Str;

class KpiStatsWidget extends StatsOverviewWidget
{
    protected ?string $heading = 'Indicateurs clés';

    protected function getStats(): array
    {
        $stats = app(StatsService::class)->getKpis();

        return [
            Stat::make('Utilisateurs', number_format($stats['totalUsers'] ?? 0))
                ->description('Actifs : ' . number_format($stats['activeUsers'] ?? 0))
                ->color('primary')
                ->icon('heroicon-m-users'),
            Stat::make('Niveaux', number_format($stats['totalLevels'] ?? 0))
                ->description('Fichier seed prêt')
                ->color('info')
                ->icon('heroicon-m-map'),
            Stat::make('Batailles', number_format($stats['totalBattles'] ?? 0))
                ->description('Actives : ' . number_format($stats['activeBattles'] ?? 0))
                ->color('warning')
                ->icon('heroicon-m-bolt'),
        ];
    }
}

