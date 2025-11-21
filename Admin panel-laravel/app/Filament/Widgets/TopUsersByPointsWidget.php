<?php

namespace App\Filament\Widgets;

use App\Models\User;
use Filament\Tables;
use Filament\Tables\Columns\TextColumn;
use Filament\Widgets\TableWidget;
use Illuminate\Database\Eloquent\Builder;

class TopUsersByPointsWidget extends TableWidget
{
    protected static ?string $heading = 'Top joueurs (points)';

    protected int|string|array $columnSpan = 'full';

    protected function getTableQuery(): Builder
    {
        return User::query()
            ->select(['id', 'displayName', 'email', 'points'])
            ->orderByDesc('points');
    }

    protected function getTableColumns(): array
    {
        return [
            TextColumn::make('displayName')
                ->label('Nom')
                ->formatStateUsing(fn ($state, User $record) => $state ?? $record->email ?? $record->id)
                ->searchable(),
            TextColumn::make('points')
                ->label('Points')
                ->sortable()
                ->alignRight(),
        ];
    }

    public function getTableRecordsPerPage(): int|string|null
    {
        return 5;
    }

    protected function getTableEmptyStateIcon(): ?string
    {
        return 'heroicon-o-user-group';
    }
}

