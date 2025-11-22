<?php

namespace App\Filament\Resources\GameConfigResource\Pages;

use App\Filament\Resources\GameConfigResource;
use Filament\Resources\Pages\CreateRecord;

class CreateGameConfig extends CreateRecord
{
    protected static string $resource = GameConfigResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
