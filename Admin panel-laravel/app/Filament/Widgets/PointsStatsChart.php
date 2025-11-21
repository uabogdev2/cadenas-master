<?php

namespace App\Filament\Widgets;

use App\Services\StatsService;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Str;

class PointsStatsChart extends ChartWidget
{
    protected ?string $heading = 'Répartition des points';

    protected function getData(): array
    {
        $stats = app(StatsService::class)->getPointStats();
        $labels = collect($stats)->keys()->map(fn (string $key) => Str::headline($key));

        return [
            'datasets' => [
                [
                    'label' => 'Points',
                    'data' => collect($stats)->values()->all(),
                    'backgroundColor' => ['#fbbf24', '#34d399', '#60a5fa', '#f472b6'],
                ],
            ],
            'labels' => $labels->all(),
        ];
    }

    protected function getType(): string
    {
        return 'bar';
    }
}

