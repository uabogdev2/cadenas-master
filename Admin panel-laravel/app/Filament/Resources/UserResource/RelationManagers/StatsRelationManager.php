<?php

namespace App\Filament\Resources\UserResource\RelationManagers;

use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables;
use Filament\Tables\Table;

class StatsRelationManager extends RelationManager
{
    protected static string $relationship = 'stats';

    protected static ?string $recordTitleAttribute = 'userId';

    public function table(Table $table): Table
    {
        return $table
            ->heading('Statistiques')
            ->columns([
                Tables\Columns\TextColumn::make('totalAttempts')
                    ->label('Tentatives totales'),
                Tables\Columns\TextColumn::make('totalPlayTime')
                    ->label('Temps de jeu (s)'),
                Tables\Columns\TextColumn::make('bestTimes')
                    ->label('Meilleurs temps')
                    ->formatStateUsing(fn ($state) => json_encode($state ?? [], JSON_UNESCAPED_UNICODE))
                    ->limit(80)
                    ->wrap(),
                Tables\Columns\TextColumn::make('updatedAt')
                    ->dateTime()
                    ->label('MAJ'),
            ])
            ->headerActions([])
            ->actions([])
            ->bulkActions([]);
    }
}

