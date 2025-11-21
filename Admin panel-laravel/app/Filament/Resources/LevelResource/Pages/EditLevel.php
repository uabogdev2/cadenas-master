<?php

namespace App\Filament\Resources\LevelResource\Pages;

use App\Filament\Resources\LevelResource;
use Filament\Resources\Pages\EditRecord;

class EditLevel extends EditRecord
{
    protected static string $resource = LevelResource::class;

    protected function mutateFormDataBeforeSave(array $data): array
    {
        return LevelResource::normalizePayload($data);
    }
}

