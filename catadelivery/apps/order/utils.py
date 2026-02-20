"""
Utilidades para asignación automática de deliveries usando el algoritmo húngaro.
"""
import math
from typing import List, Dict, Tuple
from scipy.optimize import linear_sum_assignment
import numpy as np


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calcula la distancia en kilómetros entre dos puntos geográficos
    usando la fórmula de Haversine.

    Args:
        lat1: Latitud del primer punto
        lon1: Longitud del primer punto
        lat2: Latitud del segundo punto
        lon2: Longitud del segundo punto

    Returns:
        Distancia en kilómetros
    """
    # Radio de la Tierra en kilómetros
    R = 6371.0

    # Convertir grados a radianes
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)

    # Diferencias
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    # Fórmula de Haversine
    a = math.sin(dlat / 2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    distance = R * c
    return distance


def calculate_cost_matrix(riders: List[Dict], orders: List[Dict]) -> np.ndarray:
    """
    Calcula la matriz de costos para el algoritmo húngaro.
    El costo es la suma de:
    1. Distancia entre rider y store
    2. Distancia entre store y cliente (dirección de entrega)

    Args:
        riders: Lista de diccionarios con info de riders
                [{
                    'id': int,
                    'current_latitude': float,
                    'current_longitude': float,
                    ...
                }]
        orders: Lista de diccionarios con info de órdenes
                [{
                    'id': int,
                    'store_latitude': float,
                    'store_longitude': float,
                    'delivery_latitude': float,
                    'delivery_longitude': float,
                    ...
                }]

    Returns:
        Matriz numpy de costos (distancias totales en km)
    """
    n_riders = len(riders)
    n_orders = len(orders)

    # Si no hay riders u órdenes, retornar matriz vacía
    if n_riders == 0 or n_orders == 0:
        return np.array([])

    # Crear matriz de costos
    cost_matrix = np.zeros((n_riders, n_orders))

    for i, rider in enumerate(riders):
        for j, order in enumerate(orders):
            # Validar que el rider tenga ubicación
            if rider['current_latitude'] is None or rider['current_longitude'] is None:
                # Si el rider no tiene ubicación, asignar costo muy alto
                cost_matrix[i][j] = 999999.0
                continue

            # Distancia 1: Rider -> Store
            dist_rider_to_store = haversine_distance(
                rider['current_latitude'],
                rider['current_longitude'],
                order['store_latitude'],
                order['store_longitude']
            )

            # Distancia 2: Store -> Cliente
            dist_store_to_client = haversine_distance(
                order['store_latitude'],
                order['store_longitude'],
                order['delivery_latitude'],
                order['delivery_longitude']
            )

            # Costo total = suma de ambas distancias
            total_distance = dist_rider_to_store + dist_store_to_client
            cost_matrix[i][j] = total_distance

    return cost_matrix


def assign_orders_to_riders(riders: List[Dict], orders: List[Dict]) -> List[Tuple[int, int, float]]:
    """
    Asigna órdenes a riders usando el algoritmo húngaro para minimizar
    la distancia total recorrida.

    Args:
        riders: Lista de diccionarios con info de riders
        orders: Lista de diccionarios con info de órdenes

    Returns:
        Lista de tuplas (rider_id, order_id, distance_km)
        Ejemplo: [(1, 5, 3.2), (2, 7, 5.1)]
    """
    import logging
    logger = logging.getLogger(__name__)

    if not riders or not orders:
        logger.warning("⚠️ [HUNGARIAN] No hay riders u órdenes para asignar")
        return []

    logger.info(f"🧮 [HUNGARIAN] Calculando matriz de costos ({len(riders)}x{len(orders)})...")

    # Calcular matriz de costos
    cost_matrix = calculate_cost_matrix(riders, orders)

    if cost_matrix.size == 0:
        logger.error("❌ [HUNGARIAN] Matriz de costos vacía")
        return []

    logger.info(f"✓ [HUNGARIAN] Matriz de costos calculada")

    # Aplicar algoritmo húngaro
    # Retorna índices de las asignaciones óptimas
    logger.info("🔢 [HUNGARIAN] Ejecutando scipy.optimize.linear_sum_assignment()...")
    rider_indices, order_indices = linear_sum_assignment(cost_matrix)
    logger.info(f"✓ [HUNGARIAN] Algoritmo completado. {len(rider_indices)} asignaciones encontradas")

    # Construir lista de asignaciones
    assignments = []
    for rider_idx, order_idx in zip(rider_indices, order_indices):
        rider_id = riders[rider_idx]['id']
        order_id = orders[order_idx]['id']
        distance = cost_matrix[rider_idx][order_idx]

        # Solo agregar asignaciones válidas (no las que tienen costo infinito)
        if distance < 999999.0:
            assignments.append((rider_id, order_id, distance))
            logger.debug(f"   • Asignación: Rider {rider_id} → Orden {order_id} ({distance:.2f} km)")

    logger.info(f"✅ [HUNGARIAN] {len(assignments)} asignaciones válidas generadas")

    return assignments


def calculate_assignment_score(rider_lat: float, rider_lon: float,
                               store_lat: float, store_lon: float,
                               client_lat: float, client_lon: float) -> float:
    """
    Calcula el score de asignación para un rider específico y una orden específica.
    Útil para calcular el score de una asignación individual.

    Args:
        rider_lat: Latitud del rider
        rider_lon: Longitud del rider
        store_lat: Latitud del store
        store_lon: Longitud del store
        client_lat: Latitud del cliente
        client_lon: Longitud del cliente

    Returns:
        Distancia total en kilómetros
    """
    dist_rider_to_store = haversine_distance(rider_lat, rider_lon, store_lat, store_lon)
    dist_store_to_client = haversine_distance(store_lat, store_lon, client_lat, client_lon)
    return dist_rider_to_store + dist_store_to_client


def calculate_delivery_fee(store_lat: float, store_lon: float,
                           delivery_lat: float, delivery_lon: float) -> float:
    """
    Calcula el costo de envío (delivery fee) basándose en la distancia
    entre el local comercial y la dirección de entrega.

    Regla de negocio: $0.10 USD por cada 100 metros recorridos.

    Args:
        store_lat: Latitud del local comercial
        store_lon: Longitud del local comercial
        delivery_lat: Latitud de la dirección de entrega
        delivery_lon: Longitud de la dirección de entrega

    Returns:
        Costo de envío en USD (float)

    Ejemplo:
        - Distancia: 2.5 km = 2500 metros
        - 2500 metros / 100 = 25 segmentos
        - 25 segmentos * $0.10 = $2.50 USD
    """
    # Calcular distancia en kilómetros
    distance_km = haversine_distance(store_lat, store_lon, delivery_lat, delivery_lon)

    # Convertir a metros y calcular segmentos de 100 metros
    distance_meters = distance_km * 1000
    segments = distance_meters / 100

    # Calcular costo: $0.10 por cada segmento de 100 metros
    delivery_fee = segments * 0.10

    # Redondear a 2 decimales
    delivery_fee = round(delivery_fee, 2)

    return delivery_fee
