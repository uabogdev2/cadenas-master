<?php

namespace App\Filament\Resources\GameConfigResource\Pages;

use App\Filament\Resources\GameConfigResource;
use Filament\Resources\Pages\ListRecords;
use App\Models\GameConfig;

class ListGameConfigs extends ListRecords
{
    protected static string $resource = GameConfigResource::class;

    protected function getHeaderActions(): array
    {
        return [
            // Only allow create if no config exists
            \Filament\Actions\CreateAction::make()
                ->visible(fn () => GameConfig::count() === 0),
        ];
    }
}
