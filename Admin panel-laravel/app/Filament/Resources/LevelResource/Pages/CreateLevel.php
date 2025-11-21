<?php

namespace App\Filament\Resources\LevelResource\Pages;

use App\Filament\Resources\LevelResource;
use Filament\Resources\Pages\CreateRecord;

class CreateLevel extends CreateRecord
{
    protected static string $resource = LevelResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        return LevelResource::normalizePayload($data);
    }
}

