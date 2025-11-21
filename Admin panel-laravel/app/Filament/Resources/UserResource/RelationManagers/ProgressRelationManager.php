<?php

namespace App\Filament\Resources\UserResource\RelationManagers;

use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables;
use Filament\Tables\Table;

class ProgressRelationManager extends RelationManager
{
    protected static string $relationship = 'progress';

    public function table(Table $table): Table
    {
        return $table
            ->heading('Progressions')
            ->columns([
                Tables\Columns\TextColumn::make('levelId')
                    ->label('Niveau')
                    ->sortable(),
                Tables\Columns\IconColumn::make('isCompleted')
                    ->label('Terminé')
                    ->boolean(),
                Tables\Columns\TextColumn::make('bestTime')
                    ->label('Meilleur temps (s)'),
                Tables\Columns\TextColumn::make('attempts')
                    ->label('Tentatives'),
                Tables\Columns\TextColumn::make('lastPlayed')
                    ->dateTime()
                    ->label('Dernière session'),
            ])
            ->headerActions([])
            ->actions([])
            ->bulkActions([]);
    }
}

