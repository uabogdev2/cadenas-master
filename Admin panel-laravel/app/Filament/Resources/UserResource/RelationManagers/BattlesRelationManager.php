<?php

namespace App\Filament\Resources\UserResource\RelationManagers;

use App\Models\Battle;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class BattlesRelationManager extends RelationManager
{
    protected static string $relationship = 'battlesAsPlayer1';

    public function table(Table $table): Table
    {
        return $table
            ->heading('Batailles')
            ->columns([
                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->colors([
                        'warning' => 'waiting',
                        'primary' => 'active',
                        'success' => 'finished',
                    ]),
                Tables\Columns\TextColumn::make('mode')
                    ->badge(),
                Tables\Columns\TextColumn::make('player1Score')
                    ->label('Score J1'),
                Tables\Columns\TextColumn::make('player2Score')
                    ->label('Score J2'),
                Tables\Columns\TextColumn::make('winner')
                    ->label('Gagnant'),
                Tables\Columns\TextColumn::make('createdAt')
                    ->dateTime()
                    ->label('Créé le'),
            ])
            ->headerActions([])
            ->actions([])
            ->bulkActions([]);
    }

    protected function getTableQuery(): Builder
    {
        $ownerKey = $this->getOwnerRecord()->getKey();

        return Battle::query()
            ->where(function (Builder $query) use ($ownerKey) {
                $query
                    ->where('player1', $ownerKey)
                    ->orWhere('player2', $ownerKey);
            });
    }
}

