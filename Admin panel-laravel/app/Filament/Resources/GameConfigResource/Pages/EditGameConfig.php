<?php

namespace App\Filament\Resources\GameConfigResource\Pages;

use App\Filament\Resources\GameConfigResource;
use Filament\Resources\Pages\EditRecord;

class EditGameConfig extends EditRecord
{
    protected static string $resource = GameConfigResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
