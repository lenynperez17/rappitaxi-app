import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'

/**
 * Ronda 283 — capa flotante que ningún contenedor puede recortar.
 *
 * EL PROBLEMA
 * -----------
 * Un menú o una lista de sugerencias con `position: absolute` queda recortado
 * por CUALQUIER antepasado que tenga `overflow` distinto de `visible`. En el
 * panel pasaba en dos sitios:
 *
 *   - El menú de los tres puntos de Usuarios: vive en un `<td>` dentro de un
 *     `overflow-x-auto` que a su vez está en un `overflow-hidden`. En las
 *     últimas filas de la tabla el menú aparecía cortado.
 *   - El buscador de direcciones al crear un viaje: el panel lateral es un
 *     `overflow-y-auto`, así que la lista de sugerencias se cortaba por abajo.
 *
 * La trampa está en que `overflow-x: auto` no deja el eje vertical en
 * `visible`: la especificación de CSS obliga a que, si un eje es `auto` o
 * `hidden`, el otro deje de ser `visible` y pase a `auto`. Un contenedor
 * pensado solo para deslizar en horizontal recorta también hacia abajo, que es
 * justo lo que nadie espera al escribirlo.
 *
 * LA SOLUCIÓN
 * -----------
 * Sacar el elemento del árbol con un portal a `document.body` y posicionarlo
 * con `position: fixed` a partir de las coordenadas del elemento que lo abre.
 * Fuera de esos contenedores, ya no hay nada que lo recorte.
 *
 * Subir el z-index NO servía: el recorte por overflow no tiene nada que ver
 * con el apilamiento. Un z-index de un millón se corta igual.
 */

/** Separación entre el elemento que abre y el panel. */
const MARGEN = 4

/** Aire mínimo hasta el borde de la ventana antes de darle la vuelta. */
const MARGEN_VENTANA = 8

interface Props {
  /** Elemento respecto al que se coloca. Si es `null` no se pinta nada. */
  anchor: HTMLElement | null
  /** Cerrar: clic fuera o tecla Escape. */
  onClose: () => void
  /** A qué lado del elemento se alinea. */
  align?: 'left' | 'right'
  /** Si se quiere que ocupe exactamente lo mismo que el elemento que lo abre. */
  matchWidth?: boolean
  children: React.ReactNode
}

export function FloatingLayer({
  anchor, onClose, align = 'left', matchWidth = false, children,
}: Props) {
  const panelRef = useRef<HTMLDivElement>(null)
  const [estilo, setEstilo] = useState<React.CSSProperties>({
    position: 'fixed',
    // Se pinta invisible hasta saber dónde va. Sin esto se ve un salto en la
    // esquina superior izquierda antes de colocarse.
    visibility: 'hidden',
    top: 0,
    left: 0,
  })

  /**
   * Coloca el panel. Se recalcula al abrir y en cada scroll o cambio de
   * tamaño, porque al estar en `fixed` ya no acompaña al contenedor: si la
   * tabla se desplaza, el panel se quedaría flotando donde estaba.
   */
  useLayoutEffect(() => {
    if (!anchor) return

    const colocar = () => {
      const a = anchor.getBoundingClientRect()
      const p = panelRef.current?.getBoundingClientRect()
      const alto = p?.height ?? 0
      const ancho = p?.width ?? 0

      // Hacia arriba si abajo no cabe pero arriba sí. Se comprueban las dos
      // cosas: con poco sitio en ambos lados es mejor dejarlo abajo, donde el
      // usuario lo espera.
      const espacioAbajo = window.innerHeight - a.bottom - MARGEN_VENTANA
      const espacioArriba = a.top - MARGEN_VENTANA
      const haciaArriba = alto > espacioAbajo && espacioArriba > espacioAbajo

      const top = haciaArriba ? a.top - alto - MARGEN : a.bottom + MARGEN

      let left = align === 'right' ? a.right - (matchWidth ? a.width : ancho) : a.left
      // Que no se salga por los lados de la ventana.
      const maxLeft = window.innerWidth - (matchWidth ? a.width : ancho) - MARGEN_VENTANA
      left = Math.max(MARGEN_VENTANA, Math.min(left, Math.max(MARGEN_VENTANA, maxLeft)))

      setEstilo({
        position: 'fixed',
        top: Math.max(MARGEN_VENTANA, top),
        left,
        ...(matchWidth ? { width: a.width } : {}),
        // Por encima de TODO lo del panel. La capa más alta que existe es el
        // modal de "Nuevo viaje" del mapa, en z-[2000]; el resto de modales
        // andan por z-50 y z-[500], y los paneles del mapa por z-[1000] y
        // z-[1100]. Con 1000 la lista de direcciones habría quedado detrás del
        // propio modal que la contiene.
        zIndex: 5000,
        visibility: 'visible',
      })
    }

    colocar()

    // `capture: true` es lo que hace que funcione: el scroll que importa es el
    // del contenedor interno (la tabla, el panel lateral), y ese no burbujea
    // hasta window. En fase de captura sí se ve pasar.
    window.addEventListener('scroll', colocar, true)
    window.addEventListener('resize', colocar)
    return () => {
      window.removeEventListener('scroll', colocar, true)
      window.removeEventListener('resize', colocar)
    }
  }, [anchor, align, matchWidth, children])

  /** Cerrar al tocar fuera o con Escape. */
  useEffect(() => {
    if (!anchor) return

    const fuera = (e: MouseEvent) => {
      const t = e.target as Node
      // El propio elemento que abre queda excluido: si no, su clic cerraría
      // aquí y volvería a abrir en su onClick, y el menú no se cerraría nunca.
      if (panelRef.current?.contains(t) || anchor.contains(t)) return
      onClose()
    }
    const escape = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }

    document.addEventListener('mousedown', fuera)
    document.addEventListener('keydown', escape)
    return () => {
      document.removeEventListener('mousedown', fuera)
      document.removeEventListener('keydown', escape)
    }
  }, [anchor, onClose])

  if (!anchor) return null

  return createPortal(
    <div ref={panelRef} style={estilo}>
      {children}
    </div>,
    document.body,
  )
}
