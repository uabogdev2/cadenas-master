<?php

namespace App\Filament\Resources\UserResource\RelationManagers;

use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables;
use Filament\Tables\Table;

class UnlockedHintsRelationManager extends RelationManager
{
    protected static string $relationship = 'unlockedHints';

    public function table(Table $table): Table
    {
        return $table
            ->heading('Indices débloqués')
            ->columns([
                Tables\Columns\TextColumn::make('levelId')
                    ->label('Niveau')
                    ->sortable(),
                Tables\Columns\TextColumn::make('indices')
                    ->label('Indices')
                    ->formatStateUsing(fn ($state) => json_encode($state ?? [], JSON_UNESCAPED_UNICODE))
                    ->limit(80)
                    ->wrap(),
                Tables\Columns\TextColumn::make('createdAt')
                    ->dateTime()
                    ->label('Débloqué le'),
            ])
            ->headerActions([])
            ->actions([])
            ->bulkActions([]);
    }
}

