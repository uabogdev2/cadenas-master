<?php

namespace App\Models;

use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;

class Admin extends Authenticatable implements FilamentUser
{
    use HasFactory;

    protected $table = 'admins';

    protected $primaryKey = 'userId';

    public $incrementing = false;

    protected $keyType = 'string';

    public const CREATED_AT = 'createdAt';
    public const UPDATED_AT = 'updatedAt';

    protected $fillable = [
        'userId',
        'password',
        'isAdmin',
        'permissions',
        'createdAt',
        'updatedAt',
    ];

    protected $attributes = [
        'permissions' => '{}',
    ];

    protected $casts = [
        'permissions' => 'array',
        'isAdmin' => 'boolean',
        'password' => 'hashed',
        'createdAt' => 'datetime',
        'updatedAt' => 'datetime',
    ];

    protected $hidden = [
        'password',
    ];

    public function getAuthIdentifierName(): string
    {
        return 'userId';
    }

    public function getRememberTokenName(): ?string
    {
        return null;
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'userId');
    }

    public function getNameAttribute(): string
    {
        return $this->user?->displayName ?? $this->userId;
    }

    public function getEmailAttribute(): ?string
    {
        return $this->user?->email;
    }

    public function canAccessPanel(Panel $panel): bool
    {
        return $this->isAdmin && !empty($this->email);
    }

    public function canManageUsers(): bool
    {
        return $this->hasPermission('manageUsers');
    }

    public function canManageLevels(): bool
    {
        return $this->hasPermission('manageLevels');
    }

    public function canManageBattles(): bool
    {
        return $this->hasPermission('manageBattles');
    }

    public function canManageAdmins(): bool
    {
        return $this->hasPermission('manageAdmins');
    }

    public function canViewStats(): bool
    {
        return $this->hasPermission('viewStats');
    }

    protected function hasPermission(string $key): bool
    {
        return (bool) data_get($this->permissions, $key, false);
    }
}

