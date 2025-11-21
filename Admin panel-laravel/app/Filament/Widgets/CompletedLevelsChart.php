<?php

namespace App\Filament\Widgets;

use App\Services\StatsService;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Str;

class CompletedLevelsChart extends ChartWidget
{
    protected ?string $heading = 'Niveaux complétés';

    protected function getData(): array
    {
        $stats = app(StatsService::class)->getCompletedLevelsStats();
        $labels = collect($stats)->keys()->map(fn (string $key) => Str::headline($key));

        return [
            'datasets' => [
                [
                    'label' => 'Niveaux',
                    'data' => collect($stats)->values()->all(),
                    'backgroundColor' => ['#34d399', '#10b981', '#059669', '#047857'],
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

